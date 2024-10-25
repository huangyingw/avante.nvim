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

local function load_repo_map()
  if repo_map_lib then return true end
  
  local os_name = vim.loop.os_uname().sysname:lower()
  local ext = os_name == "linux" and "so" or (os_name == "darwin" and "dylib" or "dll")
  
  local paths = {
    vim.fn.expand("~/loadrc/avante.nvim/build/avante_repo_map." .. ext),
    vim.fn.expand("~/loadrc/avante.nvim/lua/avante/avante_repo_map." .. ext)
  }
  
  for _, path in ipairs(paths) do
    if vim.fn.filereadable(path) == 1 then
      local ok, lib = pcall(require, "avante_repo_map")
      if ok then
        repo_map_lib = lib
        return true
      end
    end
  end
  return false
end

RepoMap.stringify_definitions = function(lang, content)
  if not load_repo_map() then return "" end
  return repo_map_lib.stringify_definitions(lang, content)
end

return RepoMap
