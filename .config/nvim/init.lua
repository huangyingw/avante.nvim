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

      -- 定义图片保存路径
      local image_save_path = vim.fn.stdpath("data") .. "/avante/images"

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
            behaviour = {
              support_paste_from_clipboard = true, -- 启用图片粘贴功能
            },
            claude = {
              endpoint = "https://api.anthropic.com/v1",
              model = "claude-3-haiku-20240307",
              timeout = 30000,
              temperature = 0,
              max_tokens = 4096,
              on_error = function(result)
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
          
          -- 设置 AvanteInput 缓冲区的 ctrl+v 处理
          vim.api.nvim_create_autocmd("FileType", {
            pattern = "AvanteInput",
            callback = function()
              vim.keymap.set({"n", "i"}, "<C-v>", function()
                local ok, img_clip = pcall(require, "img-clip")
                if not ok then
                  -- 如果 img-clip 加载失败，使用系统默认粘贴
                  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-v>", true, true, true), "m", true)
                  return
                end
                
                local result = img_clip.paste_image({
                  dir_path = image_save_path,  -- 使用变量
                  use_absolute_path = true,
                  show_notification = true,
                })
                if not result then
                  -- 如果图片粘贴失败，使用系统默认粘贴
                  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-v>", true, true, true), "m", true)
                end
              end, { buffer = true, noremap = true })
            end,
          })
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
            dir_path = image_save_path,  -- 使用相同的变量
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
