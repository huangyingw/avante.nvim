local Config = require("avante.config")

-- 禁用所有工具
Config.override({
  disabled_tools = {
    "rag_search",
    "python",
    "git_diff",
    "git_commit",
    "list_files",
    "search_files",
    "search_keyword",
    "read_file_toplevel_symbols",
    "read_file",
    "create_file",
    "rename_file",
    "delete_file",
    "create_dir",
    "rename_dir",
    "delete_dir",
    "bash",
    "fetch",
    "web_search"
  }
})

vim.notify("已禁用所有Avante工具功能", vim.log.levels.INFO)

return {
  -- 如果需要，可以提供函数来启用工具
  enable_tools = function()
    Config.override({
      disabled_tools = {}
    })
    vim.notify("已启用Avante工具功能", vim.log.levels.INFO)
  end
} 