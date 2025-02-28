---NOTE: this module is inspired by https://github.com/HakonHarnes/img-clip.nvim/tree/main
---@see https://github.com/ekickx/clipboard-image.nvim/blob/main/lua/clipboard-image/paste.lua

local Path = require("plenary.path")
local Utils = require("avante.utils")
local Config = require("avante.config")
local Logger = require("avante.logger")
---@module "img-clip"
local ImgClip = nil

---@class AvanteClipboard
---@field get_base64_content fun(filepath: string): string | nil
---
---@class avante.Clipboard: AvanteClipboard
local M = {}

---@type Path
local paste_directory = nil

---@return Path
local function get_paste_directory()
  if paste_directory then return paste_directory end
  paste_directory = Path:new(Config.history.storage_path):joinpath("pasted_images")
  return paste_directory
end

M.support_paste_image = Config.support_paste_image

function M.setup()
  Logger.write_log("初始化剪贴板处理...")
  get_paste_directory()

  -- 确保目录存在
  if not paste_directory:exists() then 
    Logger.write_log("创建粘贴图片目录: " .. paste_directory:absolute())
    pcall(function() paste_directory:mkdir({ parents = true }) end)
    
    -- 二次检查目录是否创建成功
    if not paste_directory:exists() then
      local full_path = paste_directory:absolute()
      Logger.write_log("尝试使用系统命令创建目录: " .. full_path)
      vim.fn.system("mkdir -p " .. vim.fn.shellescape(full_path))
      
      -- 三次检查并尝试创建子目录
      if not paste_directory:exists() then
        Logger.write_log("警告: 无法创建目录，尝试使用备用方法...")
        local home_dir = vim.fn.expand("~")
        paste_directory = Path:new(home_dir):joinpath(".cache/avante/pasted_images")
        vim.fn.system("mkdir -p " .. vim.fn.shellescape(paste_directory:absolute()))
        Logger.write_log("使用备用目录: " .. paste_directory:absolute())
      end
    end
  end

  if M.support_paste_image() and ImgClip == nil then 
    Logger.write_log("加载img-clip模块")
    pcall(function() ImgClip = require("img-clip") end)
  end
  
  Logger.write_log("剪贴板初始化完成")
end

---@param line? string
function M.paste_image(line)
  line = line or nil
  if not Config.support_paste_image() then return false end

  -- 直接检查是否是图片路径
  if line and (line:match("%.png$") or line:match("%.jpg$") or line:match("%.jpeg$")) then
    Logger.write_log("直接处理图片路径: " .. line)
    if vim.fn.filereadable(line) == 1 then
      Logger.write_log("图片文件存在")
      return true
    else
      Logger.write_log("图片文件不存在: " .. line)
    end
  end

  local opts = {
    dir_path = paste_directory:absolute(),
    prompt_for_file_name = false,
    filetypes = {
      AvanteInput = { url_encode_path = true, template = "\nimage: $FILE_PATH\n" },
    },
  }

  if vim.fn.has("wsl") > 0 or vim.fn.has("win32") > 0 then opts.use_absolute_path = true end

  Logger.write_log("尝试粘贴图片...")
  if ImgClip then
    ---@diagnostic disable-next-line: need-check-nil, undefined-field
    return ImgClip.paste_image(opts, line)
  else
    Logger.write_log("警告: img-clip未加载")
    return false
  end
end

-- 添加图片标记
---@param bufnr number 缓冲区号
---@param image_path string 图片路径
function M.add_image_tag(bufnr, image_path)
  Logger.write_log("为图片添加标记: " .. image_path)
  
  local tagged_lines = {"", "image: " .. image_path, ""}
  
  -- 检查并设置modifiable
  local was_modifiable = vim.api.nvim_buf_get_option(bufnr, "modifiable")
  if not was_modifiable then
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  end
  
  -- 在缓冲区末尾添加图片标记
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, tagged_lines)
  local last_line = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_win_set_cursor(0, { last_line, 0 })
  
  -- 恢复modifiable
  if not was_modifiable then
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
  end
  
  Logger.write_log("图片标记添加成功")
  return true
end

-- 检查是否是图片文件路径
---@param text string
---@return boolean
function M.is_image_path(text)
  if not text or text == "" then
    return false
  end
  
  -- 清理路径前后空白
  text = vim.fn.trim(text)
  
  -- 检查文件扩展名
  local is_image_ext = text:match("%.png$") or text:match("%.jpg$") or
                       text:match("%.jpeg$") or text:match("%.gif$") or
                       text:match("%.webp$") or text:match("%.bmp$")
  
  -- 检查文件是否存在
  local exists = is_image_ext and vim.fn.filereadable(text) == 1
  
  Logger.write_log("检查是否图片路径: " .. text .. " - " .. tostring(exists))
  return exists
end

-- 专门处理粘贴，尤其是macOS上的Cmd+V
function M.handle_paste()
  local Logger = require("avante.logger")
  Logger.write_log("处理粘贴操作")

  -- 获取当前缓冲区和文件类型
  local bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
  
  -- 仅在AvanteInput缓冲区中处理
  if filetype ~= "AvanteInput" then
    Logger.write_log("不在AvanteInput缓冲区中，跳过粘贴处理")
    -- 执行普通粘贴
    local mode = vim.api.nvim_get_mode().mode
    if mode == "i" then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-r>+", true, false, true), "n", true)
    elseif mode == "n" or mode == "v" or mode == "V" then
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('"+p', true, false, true), "n", true)
    end
    return true
  end
  
  Logger.write_log("在AvanteInput中处理粘贴")
  
  -- 获取当前模式
  local mode = vim.api.nvim_get_mode().mode
  Logger.write_log("当前模式: " .. mode)
  
  -- 检查是否是macOS系统
  local is_mac = vim.fn.has("mac") == 1
  if is_mac then
    Logger.write_log("检测到macOS系统，使用macOS特定粘贴处理")
    
    -- 确保粘贴目录存在
    local paste_dir = vim.fn.expand("~/.cache/avante/pasted_images")
    if vim.fn.isdirectory(paste_dir) == 0 then
      vim.fn.mkdir(paste_dir, "p")
    end
    
    -- 生成唯一的图片文件名
    local timestamp = os.date("%Y-%m-%d-%H-%M-%S")
    local random_num = math.random(100000, 999999)
    local image_path = paste_dir .. "/" .. timestamp .. "_" .. random_num .. ".png"
    
    -- 使用pbpaste获取剪贴板内容
    Logger.write_log("使用pbpaste获取剪贴板内容")
    local clipboard_text = vim.fn.system("pbpaste"):gsub("^%s+", ""):gsub("%s+$", "")
    
    -- 检查剪贴板内容是否是图片路径
    local is_image_path = clipboard_text:match("%.png$") or clipboard_text:match("%.jpg$") or 
                         clipboard_text:match("%.jpeg$") or clipboard_text:match("%.webp$") or 
                         clipboard_text:match("%.gif$") or clipboard_text:match("%.bmp$")
    
    if is_image_path and vim.fn.filereadable(clipboard_text) == 1 then
      Logger.write_log("检测到有效图片路径: " .. clipboard_text)
      
      -- 添加图片标记到缓冲区
      local was_modifiable = vim.api.nvim_buf_get_option(bufnr, "modifiable")
      if not was_modifiable then
        vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
      end
      
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"", "image: " .. clipboard_text, ""})
      local last_line = vim.api.nvim_buf_line_count(bufnr)
      vim.api.nvim_win_set_cursor(0, {last_line, 0})
      
      if not was_modifiable then
        vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
      end
      
      Logger.write_log("成功添加图片标记")
      return true
    end
    
    -- 尝试使用pngpaste工具直接保存剪贴板中的图片
    Logger.write_log("尝试使用pngpaste保存剪贴板图片")
    local has_pngpaste = vim.fn.executable("pngpaste") == 1
    
    if not has_pngpaste then
      Logger.write_log("未检测到pngpaste工具，尝试安装")
      -- 尝试使用homebrew安装pngpaste
      vim.fn.system("which brew > /dev/null && brew install pngpaste")
      has_pngpaste = vim.fn.executable("pngpaste") == 1
    end
    
    if has_pngpaste then
      Logger.write_log("使用pngpaste保存图片到: " .. image_path)
      local result = vim.fn.system("pngpaste '" .. image_path .. "' 2>/dev/null")
      local success = (vim.v.shell_error == 0 and vim.fn.filereadable(image_path) == 1)
      
      -- 验证文件大小以确认图片内容有效
      if success and vim.fn.getfsize(image_path) > 100 then
        Logger.write_log("pngpaste成功保存图片")
        
        -- 添加图片标记到缓冲区
        local was_modifiable = vim.api.nvim_buf_get_option(bufnr, "modifiable")
        if not was_modifiable then
          vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
        end
        
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"", "image: " .. image_path, ""})
        local last_line = vim.api.nvim_buf_line_count(bufnr)
        vim.api.nvim_win_set_cursor(0, {last_line, 0})
        
        if not was_modifiable then
          vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
        end
        
        Logger.write_log("成功添加图片标记")
        return true
      else
        -- 删除可能创建的空文件
        if vim.fn.filereadable(image_path) == 1 then
          vim.fn.delete(image_path)
        end
        Logger.write_log("pngpaste未能保存有效图片，尝试使用AppleScript")
      end
    else
      Logger.write_log("pngpaste工具不可用，尝试使用AppleScript")
    end
    
    -- 使用AppleScript作为备选方案
    Logger.write_log("使用AppleScript保存剪贴板图片")
    local as_cmd = "osascript -e 'tell application \"System Events\" to ¬\n" ..
              "    if the clipboard contains picture data then\n" ..
              "        set the_picture to the clipboard as «class PNGf»\n" ..
              "        set the_file to open for access (POSIX file \"" .. image_path .. "\") with write permission\n" ..
              "        write the_picture to the_file\n" ..
              "        close access the_file\n" ..
              "        return \"success\"\n" ..
              "    else\n" ..
              "        return \"no picture\"\n" ..
              "    end if\n" ..
              "end tell'"
    
    Logger.write_log("执行AppleScript")
    local as_result = vim.fn.system(as_cmd):gsub("%s+", "")
    Logger.write_log("AppleScript结果: " .. as_result)
    
    if (as_result == "success" or as_result == "") and vim.fn.filereadable(image_path) == 1 and vim.fn.getfsize(image_path) > 100 then
      Logger.write_log("AppleScript成功保存图片")
      
      -- 添加图片标记到缓冲区
      local was_modifiable = vim.api.nvim_buf_get_option(bufnr, "modifiable")
      if not was_modifiable then
        vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
      end
      
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"", "image: " .. image_path, ""})
      local last_line = vim.api.nvim_buf_line_count(bufnr)
      vim.api.nvim_win_set_cursor(0, {last_line, 0})
      
      if not was_modifiable then
        vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
      end
      
      Logger.write_log("成功添加图片标记")
      return true
    else
      -- 删除可能创建的空文件
      if vim.fn.filereadable(image_path) == 1 then
        vim.fn.delete(image_path)
      end
      Logger.write_log("AppleScript未能保存图片，尝试普通粘贴")
    end
  end
  
  -- 如果图片处理失败或不是macOS，执行普通粘贴
  Logger.write_log("执行普通粘贴操作")
  
  -- 记录粘贴前的行数
  local line_count_before = vim.api.nvim_buf_line_count(bufnr)
  Logger.write_log("粘贴前行数: " .. line_count_before)
  
  -- 记录粘贴前检查剪贴板内容
  local clipboard_content = vim.fn.getreg('+')
  Logger.write_log("粘贴前剪贴板内容: " .. (clipboard_content or "空"))
  
  -- 清理剪贴板内容
  if clipboard_content then
    clipboard_content = vim.fn.trim(clipboard_content)
  end
  
  -- 检查是否是潜在图片路径
  local is_potential_image = clipboard_content and (
    clipboard_content:match("%.png$") or clipboard_content:match("%.jpg$") or 
    clipboard_content:match("%.jpeg$") or clipboard_content:match("%.webp$") or 
    clipboard_content:match("%.gif$") or clipboard_content:match("%.bmp$")
  )
  
  -- 检查是否已经有image:前缀
  local has_prefix = clipboard_content and clipboard_content:match("^%s*image:") ~= nil
  
  -- 检查文件是否存在
  local file_exists = false
  local real_path = clipboard_content
  
  if is_potential_image and not has_prefix then
    file_exists = vim.fn.filereadable(clipboard_content) == 1
    
    -- 如果文件不存在，尝试解析相对路径
    if not file_exists then
      real_path = vim.fn.expand("%:p:h") .. "/" .. clipboard_content
      file_exists = vim.fn.filereadable(real_path) == 1
      
      if not file_exists then
        real_path = vim.fn.getcwd() .. "/" .. clipboard_content
        file_exists = vim.fn.filereadable(real_path) == 1
      end
    end
    
    if file_exists then
      Logger.write_log("剪贴板中检测到有效图片路径: " .. real_path)
      
      -- 直接插入带前缀的图片路径
      local was_modifiable = vim.api.nvim_buf_get_option(bufnr, "modifiable")
      if not was_modifiable then
        vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
      end
      
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, {"", "image: " .. real_path, ""})
      local last_line = vim.api.nvim_buf_line_count(bufnr)
      vim.api.nvim_win_set_cursor(0, {last_line, 0})
      
      if not was_modifiable then
        vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
      end
      
      Logger.write_log("成功直接添加图片标记")
      return true
    end
  end
  
  -- 执行普通粘贴
  if mode == "i" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-r>+", true, false, true), "n", true)
  elseif mode == "n" or mode == "v" or mode == "V" then
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('"+p', true, false, true), "n", true)
  end
  
  -- 等待粘贴完成
  vim.cmd("sleep 100m")
  
  -- 记录粘贴后的行数
  local line_count_after = vim.api.nvim_buf_line_count(bufnr)
  Logger.write_log("粘贴后行数: " .. line_count_after)
  
  -- 检查新添加的内容是否包含图片路径
  if line_count_after > line_count_before then
    local new_lines = vim.api.nvim_buf_get_lines(bufnr, line_count_before, line_count_after, false)
    
    for i, line in ipairs(new_lines) do
      -- 检查是否有图片路径但没有前缀image:
      if (line:match("%.png$") or line:match("%.jpg$") or line:match("%.jpeg$") or 
          line:match("%.webp$") or line:match("%.gif$") or line:match("%.bmp$")) and 
         not line:match("^%s*image:") then
        
        Logger.write_log("检测到图片路径但没有image:前缀: " .. line)
        
        -- 去除前后空格
        local clean_line = vim.fn.trim(line)
        
        -- 检查文件是否存在
        local file_exists = vim.fn.filereadable(clean_line) == 1
        local real_path = clean_line
        
        -- 如果文件不存在，尝试解析相对路径
        if not file_exists then
          real_path = vim.fn.expand("%:p:h") .. "/" .. clean_line
          file_exists = vim.fn.filereadable(real_path) == 1
          
          if not file_exists then
            real_path = vim.fn.getcwd() .. "/" .. clean_line
            file_exists = vim.fn.filereadable(real_path) == 1
          end
        end
        
        if file_exists then
          Logger.write_log("确认有效图片路径: " .. real_path)
          
          -- 修改缓冲区，添加image:前缀
          local was_modifiable = vim.api.nvim_buf_get_option(bufnr, "modifiable")
          if not was_modifiable then
            vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
          end
          
          -- 删除原始行并添加带前缀的行
          vim.api.nvim_buf_set_lines(bufnr, line_count_before + i - 1, line_count_before + i, false, {"image: " .. real_path})
          
          if not was_modifiable then
            vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
          end
          
          Logger.write_log("已修正图片路径: " .. real_path)
          
          -- 通知用户修复了图片路径
          vim.api.nvim_echo({{"已添加image:前缀到图片路径", "None"}}, false, {})
        else
          Logger.write_log("图片文件不存在: " .. clean_line .. "，尝试相对路径也无效")
        end
      end
    end
  end
  
  -- 延迟返回，确保粘贴操作完成
  vim.defer_fn(function()
    Logger.write_log("粘贴操作完成")
  end, 100)
  
  return true
end

---@param filepath string
function M.get_base64_content(filepath)
  local os_mapping = Utils.get_os_name()

  ---@type vim.SystemCompleted
  local output
  local cmd
  if os_mapping == "darwin" or os_mapping == "linux" then
    Logger.write_log("File to convert: " .. filepath .. ", exists: " .. tostring(vim.fn.filereadable(filepath)))
    cmd = ("cat %s | base64 | tr -d '\n'"):format(filepath)
  else
    cmd = ("([Convert]::ToBase64String([IO.File]::ReadAllBytes('%s')) -replace '`r`n')"):format(filepath)
  end

  Logger.write_log("Running command: " .. cmd)
  output = Utils.shell_run(cmd)
  Logger.write_log("Command exit code: " .. output.code)

  if output.code == 0 then
    Logger.write_log("Base64 length: " .. #output.stdout)
    return output.stdout
  else
    Logger.write_log("Error: " .. (output.stderr or "unknown error"))
    error("Failed to convert image to base64")
  end
end

M.get_paste_status = function()
  if vim.bo.filetype == 'AvanteInput' then
    return "Paste Mode: Image Ready"
  end
  return ""
end

return M
