-- init.lua
vim.cmd 'set runtimepath^=~/.vim runtimepath+=~/.vim/after'
vim.cmd 'let &packpath = &runtimepath'

-- 禁用终端的 GUI 颜色支持
vim.o.termguicolors = false

-- 设置当前的颜色方案为 'vim'
vim.cmd('colorscheme vim')

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
            save_format = "png",
            show_notification = true,
            is_verbose = true,
            debug = true,
            paste_command = function()
              if vim.fn.has('mac') == 1 then
                return { 'pngpaste', '-' }
              elseif vim.fn.has('unix') == 1 then
                return { 'xclip', '-selection', 'clipboard', '-t', 'image/png', '-o' }
              end
              return nil
            end,
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
}, {
  performance = {
    rtp = {
      reset = false,
      paths = {
        vim.fn.stdpath("data") .. "/lazy",
        vim.fn.expand("~/.vim"),
        vim.fn.expand("~/loadrc/avante.nvim")
      }
    }
  }
})

-- 设置推荐的 Neovim 选项
vim.opt.laststatus = 3

-- 设置图片保存路径
local image_save_path = vim.fn.stdpath("data") .. "/avante/images"
vim.fn.mkdir(image_save_path, "p")

-- 设置 AvanteInput 缓冲区的 ctrl+v 处理
vim.api.nvim_create_autocmd("FileType", {
  pattern = "AvanteInput",
  callback = function()
    vim.keymap.set({"n", "i"}, "<C-v>", function()
      -- 首先尝试获取普通剪贴板内容
      local clipboard = vim.fn.getreg('+')

      -- 如果剪贴板有普通文本内容，直接执行普通粘贴
      if clipboard ~= "" then
        vim.notify("执行普通文本粘贴", vim.log.levels.INFO)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-v>", true, true, true), "n", true)
        return
      end

      -- 尝试加载 img-clip
      local ok, img_clip = pcall(require, "img-clip")
      if not ok then
        vim.notify("Failed to load img-clip: " .. tostring(img_clip), vim.log.levels.ERROR)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-v>", true, true, true), "n", true)
        return
      end

      -- 尝试粘贴图片
      local result = img_clip.paste_image({
        dir_path = image_save_path,
        use_absolute_path = true,
        show_notification = true,
        file_name = os.date("%Y-%m-%d-%H-%M-%S") .. "_" .. tostring(os.clock()):gsub("%.", "") .. ".png",
        on_error = function(err)
          vim.notify("不是图片内容，执行普通粘贴", vim.log.levels.INFO)
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-v>", true, true, true), "n", true)
        end,
        on_success = function(path)
          vim.notify("成功粘贴图片: " .. path, vim.log.levels.INFO)
        end,
      })

      if not result then
        vim.notify("尝试普通粘贴", vim.log.levels.INFO)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-v>", true, true, true), "n", true)
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

-- 设置 AvanteInput 和 AvanteOutput 缓冲区启用复制功能
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
    vim.api.nvim_win_set_width(0, vim.o.columns)
  end
})
