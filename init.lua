-- 引导 lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- 设置插件
require("lazy").setup({
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    version = false,
    opts = {
      -- 在这里添加任何选项
    },
    build = "make BUILD_FROM_SOURCE=true",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
      "zbirenbaum/copilot.lua",
      {
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            use_absolute_path = true,
          },
        },
      },
      {
        'MeanderingProgrammer/render-markdown.nvim',
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
  },
})

-- 在文件顶部添加
local function debug_print(msg)
  print(msg)
  vim.cmd('messages')
end

-- 在加载 avante_lib 之前添加
debug_print("Attempting to load avante_lib")
local ok, err = pcall(require, 'avante_lib')
if not ok then
  debug_print("Failed to load avante_lib: " .. tostring(err))
else
  debug_print("Successfully loaded avante_lib")
end

-- 加载 avante_lib
require('avante_lib').load()

-- 在设置 avante 之前添加
debug_print("Attempting to setup avante")
ok, err = pcall(require('avante').setup, {
  -- 您的配置在这里
})
if not ok then
  debug_print("Failed to setup avante: " .. tostring(err))
else
  debug_print("Successfully setup avante")
end

-- 设置推荐的 Neovim 选项
vim.opt.laststatus = 3

package.cpath = package.cpath .. ";/root/.local/share/nvim/lazy/avante.nvim/lua/avante/?.so"
