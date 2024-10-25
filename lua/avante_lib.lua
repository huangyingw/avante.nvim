local M = {}

M.load = function()
  local os_name = vim.loop.os_uname().sysname:lower()
  local ext = os_name == "linux" and "so" or (os_name == "darwin" and "dylib" or "dll")
  
  local dev_path = vim.fn.expand("~/loadrc/avante.nvim/build/avante_repo_map." .. ext)
  if vim.fn.filereadable(dev_path) == 1 then
    local lib_path = vim.fn.expand("~/loadrc/avante.nvim/build/?." .. ext)
    package.cpath = package.cpath .. ";" .. lib_path
    return
  end
  
  error("Could not find library in build directory")
end

return M
