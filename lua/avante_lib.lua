local M = {}

local function get_library_path()
  local os_name = vim.loop.os_uname().sysname:lower()
  local ext = os_name == "linux" and "so" or (os_name == "darwin" and "dylib" or "dll")
  
  -- 添加调试信息
  local function debug_print(msg)
    print(msg)
    vim.cmd('messages')
  end
  
  -- 检查本地开发目录的 build 目录
  local dev_build_path = vim.fn.expand("~/loadrc/avante.nvim/build/avante_repo_map." .. ext)
  debug_print("Checking build path: " .. dev_build_path)
  
  if vim.fn.filereadable(dev_build_path) == 1 then
    -- 如果文件存在于 build 目录，直接使用
    debug_print("Found library in build directory")
    return dev_build_path:gsub("avante_repo_map%.", "?.")
  end
  
  -- 检查插件目录
  local plugin_path = vim.fn.stdpath("data") .. "/lazy/avante.nvim/lua/avante/avante_repo_map." .. ext
  debug_print("Checking plugin path: " .. plugin_path)
  
  if vim.fn.filereadable(plugin_path) == 1 then
    debug_print("Found library in plugin directory")
    return plugin_path:gsub("avante_repo_map%.", "?.")
  end
  
  error("Library not found in any location")
end

M.load = function()
  local os_name = vim.loop.os_uname().sysname:lower()
  local ext = os_name == "linux" and "so" or (os_name == "darwin" and "dylib" or "dll")
  
  -- 检测 Neovim 的架构
  local nvim_info = vim.fn.system("file -b " .. vim.v.progpath)
  local nvim_arch = nvim_info:match("x86_64") and "x86_64" or "arm64"
  print("Loading for architecture: " .. nvim_arch)
  
  -- 检查本地开发目录
  local dev_path = vim.fn.expand("~/loadrc/avante.nvim/build/avante_repo_map." .. ext)
  if vim.fn.filereadable(dev_path) == 1 then
    local lib_info = vim.fn.system("file -b " .. dev_path)
    print("Library info: " .. lib_info)
    
    if lib_info:match(nvim_arch) then
      local lib_path = vim.fn.expand("~/loadrc/avante.nvim/build/?." .. ext)
      package.cpath = package.cpath .. ";" .. lib_path
      return
    end
  end
  
  error(string.format("Could not find compatible library (need %s architecture)", nvim_arch))
end

return M
