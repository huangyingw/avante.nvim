-- init.lua
vim.cmd 'set runtimepath^=~/.vim runtimepath+=~/.vim/after'
vim.cmd 'let &packpath = &runtimepath'

-- 禁用终端的 GUI 颜色支持
vim.o.termguicolors = false

-- 设置当前的颜色方案为 'vim'
vim.cmd('colorscheme vim')

vim.cmd 'source ~/.vim/plugin/common.vim'
vim.cmd 'source ~/.vimrc'

-- 设置库路径
local function setup_lib_path()
  local os_name = vim.loop.os_uname().sysname:lower()
  local ext = os_name == "linux" and "so" or (os_name == "darwin" and "dylib" or "dll")

  -- 检查本地开发目录
  local dev_path = vim.fn.expand("~/loadrc/avante.nvim/build/avante_repo_map." .. ext)
  if vim.fn.filereadable(dev_path) == 1 then
    local lib_path = vim.fn.expand("~/loadrc/avante.nvim/build/?." .. ext)
    package.cpath = package.cpath .. ";" .. lib_path
    return true
  end

  -- 检查插件目录
  local plugin_path = vim.fn.expand("~/loadrc/avante.nvim/lua/avante/avante_repo_map." .. ext)
  if vim.fn.filereadable(plugin_path) == 1 then
    local lib_path = vim.fn.expand("~/loadrc/avante.nvim/lua/avante/?." .. ext)
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
    dir = vim.fn.expand("~/loadrc/avante.nvim"),
    event = "VeryLazy",
    lazy = false,
    version = false,
    opts = {},
    build = function()
      local os_name = vim.loop.os_uname().sysname:lower()
      local ext = os_name == "linux" and "so" or (os_name == "darwin" and "dylib" or "dll")
      local build_cmd = string.format(
        "cd %s && make clean && make luajit BUILD_FROM_SOURCE=true",
        vim.fn.expand("~/loadrc/avante.nvim")
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
      require('avante').setup({
        image = {
          enabled = true,
          save_path = vim.fn.stdpath("data") .. "/avante/images",
        },
        handlers = {
          image_description = function(image_path)
            return true
          end
        },
        debug = true
      })
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

-- 设置图片保存路径
local image_save_path = vim.fn.stdpath("data") .. "/avante/images"

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
        dir_path = image_save_path,
        use_absolute_path = true,
        show_notification = true,
        -- 确保文件名只包含安全的字符
        file_name = os.date("%Y-%m-%d-%H-%M-%S") .. ".png",
        default = {
          embed_image_as_base64 = false,
          prompt_for_file_name = false,
          drag_and_drop = {
            insert_mode = true,
          },
          use_absolute_path = true,
        },
      })
      if not result then
        -- 检查剪贴板内容
        local clipboard = vim.fn.getreg('+')
        if clipboard:match("^image: ") then
          -- 如果是图片路径，直接插入
          vim.api.nvim_put({clipboard}, 'c', true, true)
        else
          -- 否则使用默认粘贴
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-v>", true, true, true), "m", true)
        end
      end
    end, { buffer = true, noremap = true })
  end,
})

-- 设置 AvanteInput 缓冲区的其他配置
vim.api.nvim_create_autocmd("FileType", {
  pattern = "AvanteInput",
  callback = function()
    -- 设置本地选项
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.opt_local.foldenable = false
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
  end
})

-- ��� AvanteInput 和 AvanteOutput 缓冲区启用复制功能
vim.api.nvim_create_autocmd("FileType", {
  pattern = {"AvanteInput", "AvanteOutput"},
  callback = function()
    -- 启用普通模式下的复制快捷键
    vim.keymap.set("n", "y", "y", { buffer = true, noremap = true })
    vim.keymap.set("n", "yy", "yy", { buffer = true, noremap = true })
    vim.keymap.set("v", "y", "y", { buffer = true, noremap = true })

    -- 启用可视模式
    vim.keymap.set("n", "v", "v", { buffer = true, noremap = true })
    vim.keymap.set("n", "V", "V", { buffer = true, noremap = true })
  end
})

-- 设置 Avante 窗口宽度
vim.api.nvim_create_autocmd("FileType", {
  pattern = {"AvanteInput", "AvanteOutput"},
  callback = function()
    -- 获取总窗口宽度
    local total_width = vim.o.columns
    -- 计算目标宽度 (80% 的总宽度)
    local target_width = math.floor(total_width * 0.8)
    -- 设置窗口宽度
    vim.api.nvim_win_set_width(0, target_width)
  end
})
