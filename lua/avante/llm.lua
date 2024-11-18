local api = vim.api
local fn = vim.fn
local uv = vim.uv

local curl = require("plenary.curl")

local Utils = require("avante.utils")
local Config = require("avante.config")
local Path = require("avante.path")
local P = require("avante.providers")
local Logger = require("avante.logger")

---@class avante.LLM
local M = {}

M.CANCEL_PATTERN = "AvanteLLMEscape"

------------------------------Prompt and type------------------------------

local group = api.nvim_create_augroup("avante_llm", { clear = true })

---@alias LlmMode "planning" | "editing" | "suggesting"
---
---@class TemplateOptions
---@field use_xml_format boolean
---@field ask boolean
---@field question string
---@field code_lang string
---@field file_content string
---@field selected_code string | nil
---@field project_context string | nil
---@field history_messages AvanteLLMMessage[]
---
---@class StreamOptions: TemplateOptions
---@field ask boolean
---@field bufnr integer
---@field instructions string
---@field mode LlmMode
---@field provider AvanteProviderFunctor | nil
---@field on_chunk AvanteChunkParser
---@field on_complete AvanteCompleteParser

---@param opts StreamOptions
M.stream = function(opts)
  local mode = opts.mode or "planning"
  ---@type AvanteProviderFunctor
  local Provider = opts.provider or P[Config.provider]
  local _, body_opts = P.parse_config(Provider)
  local max_tokens = body_opts.max_tokens or 4096

  -- Check if the instructions contains an image path
  local image_paths = {}
  local instructions = opts.instructions
  if opts.instructions:match("image: ") then
    local lines = vim.split(opts.instructions, "\n")
    for i, line in ipairs(lines) do
      if line:match("^image: ") then
        local image_path = line:gsub("^image: ", "")
        table.insert(image_paths, image_path)
        table.remove(lines, i)
      end
    end
    instructions = table.concat(lines, "\n")
  end

  Path.prompts.initialize(Path.prompts.get(opts.bufnr))

  local filepath = Utils.relative_path(api.nvim_buf_get_name(opts.bufnr))

  local template_opts = {
    use_xml_format = Provider.use_xml_format,
    ask = opts.ask, -- TODO: add mode without ask instruction
    code_lang = opts.code_lang,
    filepath = filepath,
    file_content = opts.file_content,
    selected_code = opts.selected_code,
    project_context = opts.project_context,
  }

  local system_prompt = Path.prompts.render_mode(mode, template_opts)

  ---@type AvanteLLMMessage[]
  local messages = {}

  if opts.project_context ~= nil and opts.project_context ~= "" and opts.project_context ~= "null" then
    local project_context = Path.prompts.render_file("_project.avanterules", template_opts)
    if project_context ~= "" then table.insert(messages, { role = "user", content = project_context }) end
  end

  local code_context = Path.prompts.render_file("_context.avanterules", template_opts)
  if code_context ~= "" then table.insert(messages, { role = "user", content = code_context }) end

  if opts.use_xml_format then
    table.insert(messages, { role = "user", content = string.format("<question>%s</question>", instructions) })
  else
    table.insert(messages, { role = "user", content = string.format("QUESTION:\n%s", instructions) })
  end

  local remaining_tokens = max_tokens - Utils.tokens.calculate_tokens(system_prompt)

  for _, message in ipairs(messages) do
    remaining_tokens = remaining_tokens - Utils.tokens.calculate_tokens(message.content)
  end

  if opts.history_messages then
    if Config.history.max_tokens > 0 then remaining_tokens = math.min(Config.history.max_tokens, remaining_tokens) end
    -- Traverse the history in reverse, keeping only the latest history until the remaining tokens are exhausted and the first message role is "user"
    local history_messages = {}
    for i = #opts.history_messages, 1, -1 do
      local message = opts.history_messages[i]
      local tokens = Utils.tokens.calculate_tokens(message.content)
      remaining_tokens = remaining_tokens - tokens
      if remaining_tokens > 0 then
        table.insert(history_messages, message)
      else
        break
      end
    end
    if #history_messages > 0 and history_messages[1].role == "assistant" then table.remove(history_messages, 1) end
    -- prepend the history messages to the messages table
    vim.iter(history_messages):each(function(msg) table.insert(messages, 1, msg) end)
  end

  ---@type AvantePromptOptions
  local code_opts = {
    system_prompt = system_prompt,
    messages = messages,
    image_paths = image_paths,
  }

  ---@type string
  local current_event_state = nil

  ---@type AvanteHandlerOptions
  local handler_opts = { on_chunk = opts.on_chunk, on_complete = opts.on_complete }
  ---@type AvanteCurlOutput
  local spec = Provider.parse_curl_args(Provider, code_opts)

  ---@param line string
  local function parse_stream_data(line)
    Logger.debug_response({ event = "stream_data", line = line })
    local event = line:match("^event: (.+)$")
    if event then
      current_event_state = event
      return
    end
    local data_match = line:match("^data: (.+)$")
    if data_match then
      Logger.debug_response({ event = "data_match", data = data_match })
      Provider.parse_response(data_match, current_event_state, handler_opts)
    end
  end

  local function parse_response_without_stream(data)
    Logger.debug_response({ event = "response_without_stream", data = data })
    Provider.parse_response_without_stream(data, current_event_state, handler_opts)
  end

  local completed = false

  local active_job

  local curl_body_file = fn.tempname() .. ".json"
  local json_content = vim.json.encode(spec.body)
  fn.writefile(vim.split(json_content, "\n"), curl_body_file)

  Utils.debug("curl body file:", curl_body_file)

  local function cleanup()
    if Config.debug then return end
    vim.schedule(function() fn.delete(curl_body_file) end)
  end

  active_job = curl.post(spec.url, {
    headers = spec.headers,
    proxy = spec.proxy,
    insecure = spec.insecure,
    body = curl_body_file,
    stream = function(err, data, _)
      if err then
        Logger.debug_response({ event = "curl_stream_error", error = err })
        completed = true
        opts.on_complete(err)
        return
      end
      
      if not data then 
        Logger.debug_response({ event = "curl_stream_no_data" })
        return 
      end
      
      Logger.debug_response({ 
        event = "curl_stream_data", 
        data = data,
        data_type = type(data),
        data_length = #data
      })
      
      vim.schedule(function()
        if Config.options[Config.provider] == nil and Provider.parse_stream_data ~= nil then
          Logger.debug_response({ event = "using_provider_direct", provider = Config.provider })
          Provider.parse_stream_data(data, handler_opts)
        else
          if Provider.parse_stream_data ~= nil then
            Logger.debug_response({ event = "using_provider_config", provider = Config.provider })
            Provider.parse_stream_data(data, handler_opts)
          else
            Logger.debug_response({ event = "using_local_parse" })
            parse_stream_data(data)
          end
        end
      end)
    end,
    callback = function(result)
      Logger.debug_response({ 
        event = "curl_callback", 
        status = result.status,
        headers = result.headers,
        body_size = result.body and #result.body or 0,
        body = result.body
      })
      
      active_job = nil
      cleanup()
      
      if result.status >= 400 then
        local error_body = result.body
        if type(result.body) == "string" then
          local ok, decoded = pcall(vim.json.decode, result.body)
          if ok then
            error_body = decoded
          end
        end
        
        Logger.debug_response({ 
          event = "request_error", 
          status = result.status, 
          error = error_body,
          raw_body = result.body
        })
        
        if Provider.on_error then
          Provider.on_error(result)
        else
          Utils.error(string.format("API request failed with status %d. Error: %s", 
            result.status, 
            vim.inspect(error_body)
          ), { once = true, title = "Avante" })
        end
        
        vim.schedule(function()
          if not completed then
            completed = true
            opts.on_complete(string.format("API request failed with status %d. Error: %s",
              result.status,
              vim.inspect(error_body)
            ))
          end
        end)
      end

      if spec.body.stream == false and result.status == 200 then
        Logger.debug_response({ 
          event = "non_stream_success", 
          body = result.body,
          body_type = type(result.body)
        })
        vim.schedule(function()
          completed = true
          parse_response_without_stream(result.body)
        end)
      end
    end,
  })

  api.nvim_create_autocmd("User", {
    group = group,
    pattern = M.CANCEL_PATTERN,
    once = true,
    callback = function()
      -- Error: cannot resume dead coroutine
      if active_job then
        xpcall(function() active_job:shutdown() end, function(err) return err end)
        Utils.debug("LLM request cancelled")
        active_job = nil
      end
    end,
  })

  return active_job
end

function M.cancel_inflight_request() api.nvim_exec_autocmds("User", { pattern = M.CANCEL_PATTERN }) end

return M
