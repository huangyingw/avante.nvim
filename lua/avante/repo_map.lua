local Popup = require("nui.popup")
local Utils = require("avante.utils")
local event = require("nui.utils.autocmd").event
local fn = vim.fn

local filetype_map = {
  ["javascriptreact"] = "javascript",
  ["typescriptreact"] = "typescript",
}

local RepoMap = {}
local repo_map_lib

-- 添加调试函数
local function debug_print(msg)
  print(msg)
  vim.cmd('messages')
end

-- 修改加载逻辑
local function load_repo_map()
  if repo_map_lib then return true end
  
  debug_print("开始加载 avante_repo_map")
  
  -- 检查系统信息
  local os_name = vim.loop.os_uname().sysname:lower()
  local ext = os_name == "linux" and "so" or (os_name == "darwin" and "dylib" or "dll")
  local nvim_arch = vim.fn.system("uname -m"):gsub("\n", "")
  
  debug_print("系统信息:")
  debug_print("操作系统: " .. os_name)
  debug_print("架构: " .. nvim_arch)
  debug_print("package.cpath: " .. package.cpath)
  
  -- 只保留本地开发路径
  local paths = {
    vim.fn.expand("~/loadrc/avante.nvim/build/avante_repo_map." .. ext),
    vim.fn.expand("~/loadrc/avante.nvim/lua/avante/avante_repo_map." .. ext)
  }
  
  for _, path in ipairs(paths) do
    if vim.fn.filereadable(path) == 1 then
      debug_print("尝试加载库文件: " .. path)
      
      -- 检查文件信息
      local file_info = vim.fn.system("file " .. path)
      debug_print("文件信息: " .. file_info)
      
      -- 检查文件权限
      local stat = vim.loop.fs_stat(path)
      if stat then
        debug_print("文件权限: " .. string.format("%o", stat.mode))
        -- 确保文件有执行权限
        vim.fn.system("chmod 755 " .. path)
      end
      
      -- 先尝试使用 require
      local ok, lib = pcall(require, "avante_repo_map")
      if ok then
        debug_print("通过 require 成功加载库文件")
        repo_map_lib = lib
        return true
      else
        debug_print("通过 require 加载失败: " .. tostring(lib))
        
        -- 如果 require 失败，尝试使用 package.loadlib
        ok, lib = pcall(package.loadlib, path, "luaopen_avante_repo_map")
        if ok and type(lib) == "function" then
          debug_print("通过 loadlib 成功加载库文件")
          local ok2, result = pcall(lib)
          if ok2 then
            repo_map_lib = result
            return true
          else
            debug_print("执行 luaopen 函数失败: " .. tostring(result))
          end
        else
          debug_print("通过 loadlib 加载失败: " .. tostring(lib))
        end
      end
    else
      debug_print("文件不存在: " .. path)
    end
  end
  
  debug_print("所有加载尝试都失败")
  return false
end

-- 确保库已加载的辅助函数
local function ensure_repo_map_lib()
  if not load_repo_map() then
    debug_print("Failed to load repo_map_lib")
    return false
  end
  return true
end

-- 修改原有的函数调用
RepoMap.stringify_definitions = function(lang, content)
  if not ensure_repo_map_lib() then 
    debug_print("Failed to load repo_map_lib, returning empty string")
    return "" 
  end
  return repo_map_lib.stringify_definitions(lang, content)
end

return RepoMap
