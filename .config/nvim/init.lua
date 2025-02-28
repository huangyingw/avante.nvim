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
      -- 使用修改好的handle_paste函数
      local clipboard = require("avante.clipboard")
      local result = clipboard.handle_paste()
      
      -- 如果处理失败，尝试执行普通粘贴
      if not result then
        vim.notify("自定义粘贴处理失败，尝试普通粘贴", vim.log.levels.INFO)
        local mode = vim.api.nvim_get_mode().mode
        if mode == "i" then
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-r>+", true, false, true), "n", true)
        elseif mode == "n" or mode == "v" or mode == "V" then
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('"+p', true, false, true), "n", true)
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

-- macOS 专用配置
if vim.fn.has('mac') == 1 then
  -- 添加一个测试映射来确认 Cmd 键是否被识别
  vim.api.nvim_set_keymap('i', '<D-s>',
    [[<Cmd>lua print("Cmd-T was pressed!")<CR>]],
    { noremap = true, silent = false })

  -- 修改图片粘贴映射，添加调试输出
  vim.api.nvim_set_keymap('i', '<D-v>',
    [[<Cmd>lua print("Cmd-V triggered"); require('avante.clipboard').handle_paste()<CR>]],
    { noremap = true, silent = false })
  vim.api.nvim_set_keymap('n', '<D-v>',
    [[<Cmd>lua print("Cmd-V triggered (normal)"); require('avante.clipboard').handle_paste()<CR>]],
    { noremap = true, silent = false })
  vim.api.nvim_set_keymap('v', '<D-v>',
    [[<Cmd>lua print("Cmd-V triggered (visual)"); require('avante.clipboard').handle_paste()<CR>]],
    { noremap = true, silent = false })

  -- Ctrl+V 作为备选快捷键
  vim.api.nvim_set_keymap('i', '<C-v>',
    [[<Cmd>lua print("Ctrl-V triggered"); require('avante.clipboard').handle_paste()<CR>]],
    { noremap = true, silent = false })
  vim.api.nvim_set_keymap('n', '<C-v>',
    [[<Cmd>lua print("Ctrl-V triggered (normal)"); require('avante.clipboard').handle_paste()<CR>]],
    { noremap = true, silent = false })
  vim.api.nvim_set_keymap('v', '<C-v>',
    [[<Cmd>lua print("Ctrl-V triggered (visual)"); require('avante.clipboard').handle_paste()<CR>]],
    { noremap = true, silent = false })

  -- 为所有新创建的 buffer 添加映射
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*",
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      -- 为特定 buffer 设置映射
      vim.api.nvim_buf_set_keymap(bufnr, 'i', '<D-v>', 
        [[<Cmd>lua print("Buffer-specific Cmd-V triggered"); require('avante.clipboard').handle_paste()<CR>]], 
        { noremap = true, silent = false })
      vim.api.nvim_buf_set_keymap(bufnr, 'n', '<D-v>', 
        [[<Cmd>lua print("Buffer-specific Cmd-V triggered (normal)"); require('avante.clipboard').handle_paste()<CR>]], 
        { noremap = true, silent = false })
      vim.api.nvim_buf_set_keymap(bufnr, 'v', '<D-v>', 
        [[<Cmd>lua print("Buffer-specific Cmd-V triggered (visual)"); require('avante.clipboard').handle_paste()<CR>]], 
        { noremap = true, silent = false })
      
      -- 同样为Ctrl+V设置映射
      vim.api.nvim_buf_set_keymap(bufnr, 'i', '<C-v>', 
        [[<Cmd>lua print("Buffer-specific Ctrl-V triggered"); require('avante.clipboard').handle_paste()<CR>]], 
        { noremap = true, silent = false })
      vim.api.nvim_buf_set_keymap(bufnr, 'n', '<C-v>', 
        [[<Cmd>lua print("Buffer-specific Ctrl-V triggered (normal)"); require('avante.clipboard').handle_paste()<CR>]], 
        { noremap = true, silent = false })
      vim.api.nvim_buf_set_keymap(bufnr, 'v', '<C-v>', 
        [[<Cmd>lua print("Buffer-specific Ctrl-V triggered (visual)"); require('avante.clipboard').handle_paste()<CR>]], 
        { noremap = true, silent = false })
    end
  })
end

-- 添加一个普通的按键映射用于测试
vim.api.nvim_set_keymap('i', '<C-p>',
  [[<Cmd>lua print("Ctrl-P works!"); if vim.bo.filetype == 'AvanteInput' then require('avante.clipboard').paste_image() end<CR>]],
  { noremap = true, silent = false })
