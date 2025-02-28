local M = {}

-- Log file path definition
local log_file = vim.fn.expand("~/loadrc/avante.nvim/" .. "avante_claude.log")

function M.write_log(message)
  local file = io.open(log_file, "a")
  if file then
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    file:write(string.format("[%s] %s\n", timestamp, message))
    file:close()
  end
end

function M.debug_request(url, headers, body)
  if require("avante.config").debug then
    M.write_log("\n=== Claude API Request ===")
    M.write_log("URL: " .. url)
    M.write_log("Headers: " .. vim.inspect(headers))
    M.write_log("Body: " .. vim.inspect(body))
    M.write_log("=====================\n")
  end
end

function M.debug_response(response)
  if require("avante.config").debug then
    M.write_log("\n=== Claude API Response ===")
    if type(response) == "table" then
      M.write_log("Response: " .. vim.inspect(response))
    else
      M.write_log("Response: " .. tostring(response))
    end
    M.write_log("=====================\n")
  end
end

return M
