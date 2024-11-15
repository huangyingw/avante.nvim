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

-- 在文件开始添加调试函数
local function debug_print(msg)
  print(msg)
  vim.cmd('messages')
end

-- 在这里添加任何选项
-- 在文件最开始添加
local function setup_lib_path()
  local os_name = vim.loop.os_uname().sysname:lower()
  local ext = os_name == "linux" and "so" or (os_name == "darwin" and "dylib" or "dll")

  -- 添加更多调试信息
  print("OS: " .. os_name)
  print("Architecture: " .. vim.fn.system("uname -m"):gsub("\n", ""))
  print("Extension: " .. ext)

  local function verify_lib(lib_path)
    if vim.fn.filereadable(lib_path) ~= 1 then
      debug_print("Library not found: " .. lib_path)
      return false
    end

    local file_info = vim.fn.system("file -b " .. lib_path)
    debug_print("File info: " .. file_info)

    -- 修改检查逻辑，针对 macOS 的 Mach-O 动态库
    if vim.fn.has("mac") == 1 then
      if not file_info:match("Mach%-O.*dynamically linked.*shared library") then
        debug_print("Not a valid macOS dynamic library")
        return false
      end
    else
      -- 其他平台的检查逻辑保持不变
      if not file_info:match("dynamically linked") then
        debug_print("Not a dynamic library")
        return false
      end
    end

    -- 获取 Neovim 的架构
    local nvim_info = vim.fn.system("file -b " .. vim.v.progpath)
    local nvim_arch = nvim_info:match("x86_64") and "x86_64" or "arm64"
    debug_print("Neovim architecture: " .. nvim_arch)

    -- 检查库文件架构
    local lib_arch = file_info:match("x86_64") and "x86_64" or "arm64"
    debug_print("Library architecture: " .. lib_arch)

    -- 比较架构是否匹配
    local match = nvim_arch == lib_arch
    debug_print("Architecture match: " .. tostring(match))

    return match
  end

  -- 检查本地开发目录
  local dev_path = vim.fn.expand("~/loadrc/avante.nvim/build/avante_repo_map." .. ext)
  debug_print("Checking build path: " .. dev_path)
  if verify_lib(dev_path) then
    local lib_path = vim.fn.expand("~/loadrc/avante.nvim/build/?." .. ext)
    package.cpath = package.cpath .. ";" .. lib_path
    debug_print("Package cpath after: " .. package.cpath)
    debug_print("Using build directory library")
    return true
  end

  -- 检查插件目录
  local plugin_path = vim.fn.stdpath("data") .. "/lazy/avante.nvim/lua/avante/avante_repo_map." .. ext
  debug_print("Checking plugin path: " .. plugin_path)
  if verify_lib(plugin_path) then
    local lib_path = vim.fn.stdpath("data") .. "/lazy/avante.nvim/lua/avante/?." .. ext
    package.cpath = package.cpath .. ";" .. lib_path
    debug_print("Using plugin directory library")
    return true
  end

  debug_print("No compatible library found")
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
    dir = "~/loadrc/avante.nvim",  -- 使用本地目录
    event = "VeryLazy",
    lazy = false,
    version = false,
    opts = {},
    build = function()
      local os_name = vim.loop.os_uname().sysname:lower()
      local ext = os_name == "linux" and "so" or (os_name == "darwin" and "dylib" or "dll")

      -- 检测 Neovim 的架构
      local nvim_info = vim.fn.system("file -b " .. vim.v.progpath)
      local nvim_arch = nvim_info:match("x86_64") and "x86_64" or "arm64"
      print("Building for architecture: " .. nvim_arch)

      -- 构建命令
      local build_cmd = string.format(
        "cd ~/loadrc/avante.nvim && make clean && make luajit BUILD_FROM_SOURCE=true",
        nvim_arch
      )
      print("Running build command: " .. build_cmd)

      -- 执行构建
      local result = vim.fn.system(build_cmd)
      print("Build output: " .. result)

      if vim.v.shell_error ~= 0 then
        error("Build failed: " .. result)
      end

      -- 验证构建结果
      local build_path = vim.fn.expand("~/loadrc/avante.nvim/build/avante_repo_map." .. ext)
      if vim.fn.filereadable(build_path) ~= 1 then
        error("Build succeeded but library file not found: " .. build_path)
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
      -- 检查插件是否存在
      if vim.fn.filereadable(vim.fn.expand("~/.vim/bundle/vim-anyfold/plugin/anyfold.vim")) ~= 1 then
        print("AnyFold plugin not found")
        return
      end

      -- 设置基本配置
      vim.g.anyfold_fold_display = 0
      vim.g.anyfold_fold_comments = 1

      -- 创建专用的自动命令组
      local anyfold_group = vim.api.nvim_create_augroup("anyfold_group", { clear = true })

      -- 使用 VimEnter 事件来确保插件完全加载后再初始化
      vim.api.nvim_create_autocmd("VimEnter", {
        group = anyfold_group,
        callback = function()
          -- 延迟执行以确保插件完全加载
          vim.defer_fn(function()
            if vim.fn.exists('*anyfold#init') == 1 then
              -- 初始化 anyfold，传入 0 作为参数
              vim.fn['anyfold#init'](0)
              -- 设置折叠选项
              vim.opt_local.foldmethod = "expr"
              vim.opt_local.foldexpr = "anyfold#fold()"
            end
          end, 100)  -- 延迟 100ms
        end
      })

      -- 为新打开的缓冲区设置折叠
      vim.api.nvim_create_autocmd("BufEnter", {
        group = anyfold_group,
        pattern = "*",
        callback = function()
          if vim.fn.exists('*anyfold#init') == 1 then
            -- 设置折叠选项
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
