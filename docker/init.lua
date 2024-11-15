-- init.lua
vim.cmd 'set runtimepath^=~/.vim runtimepath+=~/.vim/after'
vim.cmd 'let &packpath = &runtimepath'

-- 禁用终端的 GUI 颜色支持
vim.o.termguicolors = false

-- 设置当前的颜色方案为 'vim'
vim.cmd('colorscheme vim')

-- 设置库路径
local function setup_lib_path()
  local os_name = vim.loop.os_uname().sysname:lower()
  local ext = os_name == "linux" and "so" or (os_name == "darwin" and "dylib" or "dll")

  -- 检查本地开发目录
  local dev_path = "/root/.local/share/nvim/lazy/avante.nvim/build/avante_repo_map." .. ext
  if vim.fn.filereadable(dev_path) == 1 then
    local lib_path = "/root/.local/share/nvim/lazy/avante.nvim/build/?." .. ext
    package.cpath = package.cpath .. ";" .. lib_path
    return true
  end

  -- 检查插件目录
  local plugin_path = vim.fn.stdpath("data") .. "/lazy/avante.nvim/lua/avante/avante_repo_map." .. ext
  if vim.fn.filereadable(plugin_path) == 1 then
    local lib_path = vim.fn.stdpath("data") .. "/lazy/avante.nvim/lua/avante/?." .. ext
    package.cpath = package.cpath .. ";" .. lib_path
    return true
  end

  return false
end

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
    dir = "/root/.local/share/nvim/lazy/avante.nvim",
    event = "VeryLazy",
    lazy = false,
    version = false,
    opts = {},
    build = function()
      local os_name = vim.loop.os_uname().sysname:lower()
      local ext = os_name == "linux" and "so" or (os_name == "darwin" and "dylib" or "dll")
      local build_cmd = string.format(
        "cd /root/.local/share/nvim/lazy/avante.nvim && make clean && make luajit BUILD_FROM_SOURCE=true"
      )
      local result = vim.fn.system(build_cmd)
      if vim.v.shell_error ~= 0 then
        error("Build failed: " .. result)
      end
    end,
    config = function()
      if not setup_lib_path() then
        error("Failed to setup library path - no compatible library found")
      end
      require('avante').setup({})
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
    dir = "~/.vim/bundle/vim-anyfold",
    ft = "*",
    config = function()
      if vim.fn.filereadable(vim.fn.expand("~/.vim/bundle/vim-anyfold/plugin/anyfold.vim")) ~= 1 then
        return
      end

      vim.g.anyfold_fold_display = 0
      vim.g.anyfold_fold_comments = 1

      local anyfold_group = vim.api.nvim_create_augroup("anyfold_group", { clear = true })

      vim.api.nvim_create_autocmd("VimEnter", {
        group = anyfold_group,
        callback = function()
          vim.defer_fn(function()
            if vim.fn.exists('*anyfold#init') == 1 then
              vim.fn['anyfold#init'](0)
              vim.opt_local.foldmethod = "expr"
              vim.opt_local.foldexpr = "anyfold#fold()"
            end
          end, 100)
        end
      })

      vim.api.nvim_create_autocmd("BufEnter", {
        group = anyfold_group,
        pattern = "*",
        callback = function()
          if vim.fn.exists('*anyfold#init') == 1 then
            vim.opt_local.foldmethod = "expr"
            vim.opt_local.foldexpr = "anyfold#fold()"
          end
        end
      })
    end
  }
})

-- 设置推荐的 Neovim 选项
vim.opt.laststatus = 3
