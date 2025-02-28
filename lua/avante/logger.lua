local M = {}

-- Log file path definition
-- 使用更标准的日志路径，同时确保目录存在
local log_dir = vim.fn.stdpath("data") -- 通常是 ~/.local/share/nvim
local log_file = log_dir .. "/avante.log"

-- 确保目录存在
function M.ensure_log_dir()
  -- 打印日志路径便于调试
  print("Avante日志路径: " .. log_file)
  
  -- 确保日志目录存在
  vim.fn.mkdir(log_dir, "p")
  
  -- 测试日志文件是否可写
  local file = io.open(log_file, "a")
  if file then
    file:write(string.format("[%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), "Avante日志系统初始化"))
    file:close()
    return true
  else
    vim.api.nvim_echo({{"无法写入日志文件: " .. log_file, "ErrorMsg"}}, true, {})
    return false
  end
end

-- 初始化日志系统
M.ensure_log_dir()

function M.write_log(message)
  local file = io.open(log_file, "a")
  if file then
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    file:write(string.format("[%s] %s\n", timestamp, message))
    file:close()
  else
    -- 如果无法写入日志，尝试打印到Neovim消息区域
    vim.schedule(function()
      vim.api.nvim_echo({{"日志写入失败: " .. message, "WarningMsg"}}, false, {})
    end)
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
