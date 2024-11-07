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
      if setup_done then
        return
      end

      local ok, lib = pcall(require, 'avante_lib')
      if not ok then
        return
      end

      lib.load()

      ok, repo_map = pcall(require, "avante.repo_map")
      if not ok then
        return
      end

      if not repo_map.setup then
        repo_map.setup = function()
          return true
        end
      end

      vim.defer_fn(function()
        local ok, avante = pcall(require, 'avante')
        if not ok then
          return
        end

        if type(avante.setup) ~= "function" then
          return
        end

        ok, err = pcall(function()
          avante.setup({
            debug = true,
            provider = "claude",
            claude = {
              endpoint = "https://api.anthropic.com/v1",
              model = "claude-3-5-sonnet-20241022",
              timeout = 30000,
              temperature = 0,
              max_tokens = 4096,
              on_error = function(result)
                -- 直接打印错误信息
                if result.body then
                  local ok, body = pcall(vim.json.decode, result.body)
                  if ok and body and body.error then
                    vim.notify(
                      "Claude API Error: " .. body.error.message,
                      vim.log.levels.ERROR,
                      { title = "Avante" }
                    )
                  end
                end
                -- 记录到日志
                vim.fn.writefile(
                  {vim.fn.strftime("%Y-%m-%d %H:%M:%S") .. " Error: " .. vim.inspect(result)},
                  vim.fn.stdpath("state") .. "/avante.log",
                  "a"
                )
              end
            }
          })
        end)
        if ok then
          setup_done = true
        else
          print("Avante setup error:", err)
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
  {
    "pseewald/vim-anyfold",
    event = "VeryLazy",
  },
})

-- 设置推荐的 Neovim 选项
vim.opt.laststatus = 3
