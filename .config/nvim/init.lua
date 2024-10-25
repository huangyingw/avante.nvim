-- init.lua
vim.cmd 'set runtimepath^=~/.vim runtimepath+=~/.vim/after'
vim.cmd 'let &packpath = &runtimepath'

-- 禁用终端的 GUI 颜色支持
vim.o.termguicolors = false

-- 设置当前的颜色方案为 'vim'
vim.cmd('colorscheme vim')

vim.cmd 'source ~/.vim/plugin/common.vim'
vim.cmd 'source ~/.vimrc'

require('plugins')
require('keymaps')
require('nvim_molten_config')
-- require('secret_config')

-- 在文件顶部添加
local function debug_print(msg)
  print(msg)
  vim.cmd('messages')
end

-- 设置一个标志来跟踪是否已经设置
local setup_done = false

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
    dir = "~/loadrc/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    version = false,
    opts = {},
    config = function()
      -- 防止重复设置
      if setup_done then
        return
      end

      -- 检查 avante_lib
      debug_print("Attempting to load avante_lib")
      local ok, lib = pcall(require, 'avante_lib')
      if not ok then
        debug_print("Failed to load avante_lib: " .. tostring(lib))
        return
      end
      debug_print("Successfully loaded avante_lib")

      -- 加载库
      lib.load()

      -- 先加载 repo_map 模块
      debug_print("Loading repo_map module")
      ok, repo_map = pcall(require, "avante.repo_map")
      if not ok then
        debug_print("Failed to load repo_map: " .. tostring(repo_map))
        return
      end

      -- 添加 setup 函数
      if not repo_map.setup then
        repo_map.setup = function() 
          debug_print("Setting up repo_map")
          return true
        end
      end

      -- 延迟加载和设置
      vim.defer_fn(function()
        -- 检查 avante 模块
        debug_print("Attempting to require avante")
        local ok, avante = pcall(require, 'avante')
        if not ok then
          debug_print("Failed to require avante: " .. tostring(avante))
          return
        end
        
        -- 检查 setup 函数
        debug_print("Checking avante module")
        if type(avante.setup) ~= "function" then
          debug_print("avante.setup is not a function: " .. type(avante.setup))
          return
        end
        
        -- 使用保存的引用调用 setup
        ok, err = pcall(function()
          avante.setup({})
        end)
        if not ok then
          debug_print("Failed to setup avante: " .. tostring(err))
        else
          debug_print("Successfully setup avante")
          setup_done = true
        end
      end, 100)
    end,
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

-- 设置推荐的 Neovim 选项
vim.opt.laststatus = 3
