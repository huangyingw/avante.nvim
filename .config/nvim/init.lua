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
      -- 1. 检查剪贴板内容
      local clipboard = vim.fn.getreg('+')
      vim.notify("Clipboard content type: " .. type(clipboard), vim.log.levels.DEBUG)
      
      local ok, img_clip = pcall(require, "img-clip")
      if not ok then
        vim.notify("Failed to load img-clip: " .. tostring(img_clip), vim.log.levels.ERROR)
        return
      end

      -- 2. 检查保存路径
      vim.notify("Image save path: " .. image_save_path, vim.log.levels.DEBUG)
      
      -- 3. 检查目录权限
      local stat = vim.loop.fs_stat(image_save_path)
      vim.notify("Directory stats: " .. vim.inspect(stat), vim.log.levels.DEBUG)
      
      -- 4. 生成唯一文件名
      local file_name = os.date("%Y-%m-%d-%H-%M-%S") .. "_" .. tostring(os.clock()):gsub("%.", "") .. ".png"
      local full_path = image_save_path .. "/" .. file_name
      
      local result = img_clip.paste_image({
        dir_path = image_save_path,
        use_absolute_path = true,
        show_notification = true,
        file_name = file_name,
        on_error = function(err)
          -- 5. 详细的错误信息
          vim.notify("Failed to save image: " .. tostring(err) .. "\nStack: " .. debug.traceback(), vim.log.levels.ERROR)
        end,
        on_success = function(path)
          -- 6. 检查保存的文件
          local file_stat = vim.loop.fs_stat(path)
          vim.notify("Saved image stats: " .. vim.inspect(file_stat), vim.log.levels.INFO)
          
          -- 7. 尝试读取文件内容
          local f = io.open(path, "rb")
          if f then
            local content = f:read("*all")
            f:close()
            vim.notify("File size: " .. #content .. " bytes", vim.log.levels.INFO)
          else
            vim.notify("Cannot read saved file", vim.log.levels.ERROR)
          end
        end,
        before_paste = function()
          -- 8. 保存前的回调
          vim.notify("About to paste image", vim.log.levels.INFO)
        end,
      })

      -- 9. 检查返回结果
      vim.notify("Paste result: " .. tostring(result), vim.log.levels.DEBUG)
      
      if not result then
        local clipboard = vim.fn.getreg('+')
        vim.notify("Fallback clipboard content: " .. tostring(clipboard), vim.log.levels.DEBUG)
        if clipboard:match("^image: ") then
          vim.api.nvim_put({clipboard}, 'c', true, true)
        else
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
    -- 获取总窗口宽度
    local total_width = vim.o.columns
    -- 计算目标宽度 (80% 的总宽度)
    local target_width = math.floor(total_width * 0.8)
    -- 设置窗口宽度
    vim.api.nvim_win_set_width(0, target_width)
  end
})
