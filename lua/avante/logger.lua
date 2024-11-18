local M = {}

-- Log file path definition
local log_file = vim.fn.expand("~/loadrc/avante.nvim/" .. "avante_claude.log")

local function write_log(message)
  local file = io.open(log_file, "a")
  if file then
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    file:write(string.format("[%s] %s\n", timestamp, message))
    file:close()
  end
end

function M.debug_request(url, headers, body)
  if require("avante.config").debug then
    write_log("\n=== Claude API Request ===")
    write_log("URL: " .. url)
    write_log("Headers: " .. vim.inspect(headers))
    write_log("Body: " .. vim.inspect(body))
    write_log("=====================\n")
  end
end

function M.debug_response(response)
  if require("avante.config").debug then
    write_log("\n=== Claude API Response ===")
    if type(response) == "table" then
      write_log("Response: " .. vim.inspect(response))
    else
      write_log("Response: " .. tostring(response))
    end
    write_log("=====================\n")
  end
end

return M
