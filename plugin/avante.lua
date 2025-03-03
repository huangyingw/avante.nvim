if vim.fn.has("nvim-0.10") == 0 then
  vim.api.nvim_echo({
    { "Avante requires at least nvim-0.10", "ErrorMsg" },
    { "Please upgrade your neovim version", "WarningMsg" },
    { "Press any key to exit", "ErrorMsg" },
  }, true, {})
  vim.fn.getchar()
  vim.cmd([[quit]])
end

if vim.g.avante ~= nil then return end

vim.g.avante = 1
vim.g.avante_setup_paste = 0 -- 记录是否已设置过粘贴
vim.g.avante_debug_paste = 1 -- 启用粘贴调试

--- NOTE: We will override vim.paste if img-clip.nvim is available to work with avante.nvim internal logic paste
local Clipboard = require("avante.clipboard")
local Config = require("avante.config")
local Utils = require("avante.utils")
local Logger = require("avante.logger")
local api = vim.api

-- 完全重写macOS的粘贴处理机制
if Utils.get_os_name() == "darwin" then
  Logger.write_log("设置macOS专用粘贴处理")
  
  -- 创建一个临时脚本文件，用于更底层地拦截Cmd+V
  local temp_script = vim.fn.stdpath("data") .. "/avante_paste_fix.vim"
  local f = io.open(temp_script, "w")
  if f then
    f:write([[
" macOS Cmd+V粘贴修复脚本
if has('mac')
  " 映射D-v (Cmd+V)
  nnoremap <D-v> :call AvantePasteHandler()<CR>
  inoremap <D-v> <C-o>:call AvantePasteHandler()<CR>
  vnoremap <D-v> <C-o>:call AvantePasteHandler()<CR>
  cnoremap <D-v> <C-r>+
  tnoremap <D-v> <C-\><C-n>:call AvantePasteHandler()<CR>a
  
  " Ctrl+V作为备选
  nnoremap <C-v> :call AvantePasteHandler()<CR>
  inoremap <C-v> <C-o>:call AvantePasteHandler()<CR>
  vnoremap <C-v> <C-o>:call AvantePasteHandler()<CR>
endif

" 粘贴处理函数
function! AvantePasteHandler()
  " 调用Lua函数处理粘贴
  lua require('avante.clipboard').handle_paste()
endfunction
]])
    f:close()
    
    -- 加载临时脚本
    vim.cmd("source " .. temp_script)
    Logger.write_log("加载了macOS粘贴修复脚本: " .. temp_script)
    
    -- 在每次进入缓冲区时重新设置映射
    vim.api.nvim_create_autocmd({"VimEnter", "BufEnter"}, {
      pattern = "*",
      callback = function()
        Logger.write_log("重新设置macOS的Cmd+V映射 (VimEnter/BufEnter)")
        -- 强制重新加载脚本，确保映射一直生效
        vim.cmd("source " .. temp_script)
      end
    })
  else
    Logger.write_log("无法创建临时粘贴脚本")
  end
  
  -- 添加全局命令
  vim.api.nvim_create_user_command("AvantePaste", function()
    Logger.write_log("执行AvantePaste命令")
    require("avante.clipboard").handle_paste()
  end, {
    desc = "avante: paste from clipboard with special handling"
  })
  
  -- 添加新的直接粘贴图片命令
  vim.api.nvim_create_user_command("AvantePasteImage", function()
    Logger.write_log("执行AvantePasteImage命令 - 直接粘贴图片")
    
    -- 获取当前缓冲区
    local bufnr = vim.api.nvim_get_current_buf()
    local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
    
    -- 只在AvanteInput缓冲区中处理
    if filetype ~= "AvanteInput" then
      vim.api.nvim_echo({{"此命令只能在AvanteInput缓冲区中使用", "ErrorMsg"}}, false, {})
      return
    end
    
    -- 确保目录存在
    local paste_dir = vim.fn.expand("~/.cache/avante/pasted_images")
    if vim.fn.isdirectory(paste_dir) == 0 then
      vim.fn.mkdir(paste_dir, "p")
    end
    
    -- 生成唯一图片文件名
    local timestamp = os.date("%Y-%m-%d-%H-%M-%S")
    local random_num = math.random(100000, 999999)
    local image_path = paste_dir .. "/" .. timestamp .. "_" .. random_num .. ".png"
    
    -- 尝试使用pngpaste
    local result = vim.fn.system("pngpaste '" .. image_path .. "' 2>/dev/null")
    local success = (vim.v.shell_error == 0 and vim.fn.filereadable(image_path) == 1)
    
    if success and vim.fn.getfsize(image_path) > 100 then
      Logger.write_log("成功使用pngpaste保存图片到: " .. image_path)
      
      -- 添加图片标记
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
      
      vim.api.nvim_echo({{"成功粘贴图片", "None"}}, false, {})
    else
      -- 尝试使用AppleScript
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
      
      local as_result = vim.fn.system(as_cmd):gsub("%s+", "")
      
      if (as_result == "success" or as_result == "") and vim.fn.filereadable(image_path) == 1 then
        Logger.write_log("成功使用AppleScript保存图片到: " .. image_path)
        
        -- 添加图片标记
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
        
        vim.api.nvim_echo({{"成功粘贴图片", "None"}}, false, {})
      else
        -- 获取剪贴板内容尝试普通粘贴
        local clipboard_text = vim.fn.system("pbpaste"):gsub("^%s+", ""):gsub("%s+$", "")
        
        -- 检查是否为图片路径
        if clipboard_text:match("%.png$") or clipboard_text:match("%.jpg$") or clipboard_text:match("%.jpeg$") then
          if vim.fn.filereadable(clipboard_text) == 1 then
            -- 添加图片标记
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
            
            vim.api.nvim_echo({{"添加图片路径成功", "None"}}, false, {})
          else
            vim.api.nvim_echo({{"剪贴板内容不是图片或有效的图片路径", "WarningMsg"}}, false, {})
            Logger.write_log("剪贴板内容不是图片或有效图片路径: " .. clipboard_text:sub(1, 50))
          end
        else
          vim.api.nvim_echo({{"剪贴板内容不是图片", "WarningMsg"}}, false, {})
        end
      end
    end
  end, {
    desc = "avante: 直接粘贴剪贴板中的图片"
  })
  
  -- 创建一个快捷命令脚本用于通过快捷键直接执行粘贴图片命令
  local keycmd_script = vim.fn.stdpath("data") .. "/avante_paste_key.vim"
  local kf = io.open(keycmd_script, "w")
  if kf then
    kf:write([[
" 快捷键直接执行AvantePasteImage命令
nnoremap <F13> :AvantePasteImage<CR>
inoremap <F13> <Esc>:AvantePasteImage<CR>a
vnoremap <F13> <Esc>:AvantePasteImage<CR>gv

" 映射Alt+V(Option+V)为AvantePasteImage
nnoremap <M-v> :AvantePasteImage<CR>
inoremap <M-v> <Esc>:AvantePasteImage<CR>a
vnoremap <M-v> <Esc>:AvantePasteImage<CR>gv
]])
    kf:close()
    
    -- 加载临时脚本
    vim.cmd("source " .. keycmd_script)
    Logger.write_log("加载了快捷键粘贴图片脚本: " .. keycmd_script)
    
    -- 在每次进入缓冲区时重新设置映射
    vim.api.nvim_create_autocmd({"VimEnter", "BufEnter"}, {
      pattern = "*",
      callback = function()
        vim.cmd("source " .. keycmd_script)
      end
    })
  end
  
  -- 直接设置Alt+V键映射
  vim.api.nvim_set_keymap('n', '<M-v>', ':AvantePasteImage<CR>', {noremap = true, silent = false})
  vim.api.nvim_set_keymap('i', '<M-v>', '<Esc>:AvantePasteImage<CR>a', {noremap = true, silent = false})
  vim.api.nvim_set_keymap('v', '<M-v>', '<Esc>:AvantePasteImage<CR>gv', {noremap = true, silent = false})
  
  -- 创建一个自动命令组，用于监听粘贴事件
  vim.api.nvim_create_augroup("AvantePasteHandler", { clear = true })
  
  -- 监听粘贴事件
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = "AvantePasteHandler",
    callback = function(ev)
      if ev.event == "TextYankPost" and ev.operator == "p" then
        Logger.write_log("检测到粘贴操作")
        local bufnr = vim.api.nvim_get_current_buf()
        local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
        
        if filetype == "AvanteInput" then
          Logger.write_log("在AvanteInput缓冲区检测到粘贴")
          
          -- 检查最后一行是否有图片路径
          local last_line = vim.api.nvim_buf_line_count(bufnr)
          local lines = vim.api.nvim_buf_get_lines(bufnr, last_line - 5, last_line, false)
          
          for _, line in ipairs(lines) do
            if line:match("%.png$") or line:match("%.jpg$") or line:match("%.jpeg$") then
              if not line:match("^image:") then
                Logger.write_log("检测到图片路径但无标记: " .. line)
                
                -- 尝试修复 - 添加image标记
                local fixed = false
                for i, l in ipairs(lines) do
                  if l == line then
                    vim.api.nvim_buf_set_lines(bufnr, last_line - 5 + i - 1, last_line - 5 + i, false, {"image: " .. line})
                    fixed = true
                    Logger.write_log("已修复图片路径: " .. line)
                    break
                  end
                end
                
                if fixed then
                  vim.api.nvim_echo({{"已修复图片路径格式", "None"}}, false, {})
                end
              end
            end
          end
        end
      end
    end,
    desc = "监听粘贴事件，自动修复图片路径"
  })
  
  -- 测试函数，用于检查映射是否生效
  vim.api.nvim_create_user_command("AvanteCheckPaste", function()
    local maps = vim.api.nvim_get_keymap('n')
    local found = false
    
    for _, map in ipairs(maps) do
      if map.lhs == "<D-v>" or map.lhs == "<C-v>" or map.lhs == "<M-v>" then
        print("找到映射: " .. map.lhs .. " -> " .. map.rhs)
        found = true
      end
    end
    
    if not found then
      print("未找到粘贴相关映射!")
    end
    
    print("当前值: vim.g.avante_setup_paste = " .. tostring(vim.g.avante_setup_paste))
    print("系统类型: " .. Utils.get_os_name())
    
    -- 测试剪贴板
    local text = ""
    if Utils.get_os_name() == "darwin" then
      text = vim.fn.system("pbpaste")
    else
      text = vim.fn.getreg('+')
    end
    print("剪贴板内容(前50字符): " .. text:sub(1, 50))
    
    -- 测试监听器
    print("创建粘贴监听器状态: " .. tostring(vim.fn.exists("#AvantePasteHandler#TextYankPost")))
    
    -- 创建一个简单的回调测试
    print("尝试手动触发粘贴处理...")
    require("avante.clipboard").handle_paste()
  end, {
    desc = "检查粘贴相关设置是否正确"
  })
end

if Config.support_paste_image() then
  vim.paste = (function(overridden)
    ---@param lines string[]
    ---@param phase -1|1|2|3
    return function(lines, phase)
      require("img-clip.util").verbose = false

      local bufnr = vim.api.nvim_get_current_buf()
      local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
      
      -- 添加调试信息
      Logger.write_log("vim.paste被调用: filetype=" .. filetype .. ", phase=" .. tostring(phase))
      if lines and #lines > 0 then
        Logger.write_log("粘贴内容第一行: " .. lines[1]:sub(1, math.min(50, #lines[1])))
      end
      
      -- 非AvanteInput缓冲区使用普通粘贴
      if filetype ~= "AvanteInput" then 
        Logger.write_log("非AvanteInput缓冲区，使用常规粘贴")
        return overridden(lines, phase) 
      end
      
      -- 检查是否是图片路径
      if lines and #lines > 0 then
        local line = lines[1]:gsub("^%s+", ""):gsub("%s+$", "")
        
        -- 检查是图片路径
        if line:match("%.png$") or line:match("%.jpg$") or line:match("%.jpeg$") or 
           line:match("%.gif$") or line:match("%.webp$") or line:match("%.bmp$") then
          Logger.write_log("检测到图片路径: " .. line)
          
          -- 检查文件是否存在
          if vim.fn.filereadable(line) == 1 then
            Logger.write_log("图片文件存在，添加image标记")
            -- 使用add_image_tag函数
            Clipboard.add_image_tag(bufnr, line)
            return true
          else
            Logger.write_log("图片文件不存在: " .. line)
          end
        end
      end

      -- 尝试使用img-clip粘贴图片
      local ok = Clipboard.paste_image(lines and lines[1] or nil)
      Logger.write_log("img-clip粘贴结果: " .. tostring(ok))
      
      if not ok then
        -- 如果粘贴图片失败，退回到普通文本粘贴
        Logger.write_log("退回到普通文本粘贴")
        return overridden(lines, phase)
      end

      -- 成功粘贴图片后，添加新行并设置光标位置
      vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { "" })
      local last_line = vim.api.nvim_buf_line_count(bufnr)
      vim.api.nvim_win_set_cursor(0, { last_line, 0 })
      Logger.write_log("粘贴图片成功")
      return true
    end
  end)(vim.paste)
else
  Logger.write_log("图片粘贴功能未启用")
end

---@param n string
---@param c vim.api.keyset.user_command.callback
---@param o vim.api.keyset.user_command.opts
local cmd = function(n, c, o)
  o = vim.tbl_extend("force", { nargs = 0 }, o or {})
  api.nvim_create_user_command("Avante" .. n, c, o)
end

cmd("Ask", function(opts)
  ---@type AskOptions
  local args = { question = nil, win = {} }
  local q_parts = {}
  local q_ask = nil
  for _, arg in ipairs(opts.fargs) do
    local value = arg:match("position=(%w+)")
    local ask = arg:match("ask=(%w+)")
    if ask ~= nil then
      q_ask = ask == "true"
    elseif value then
      args.win.position = value
    else
      table.insert(q_parts, arg)
    end
  end
  require("avante.api").ask(
    vim.tbl_deep_extend("force", args, { ask = q_ask, question = #q_parts > 0 and table.concat(q_parts, " ") or nil })
  )
end, {
  desc = "avante: ask AI for code suggestions",
  nargs = "*",
  complete = function(_, _, _)
    local candidates = {} ---@type string[]
    vim.list_extend(
      candidates,
      ---@param x string
      vim.tbl_map(function(x) return "position=" .. x end, { "left", "right", "top", "bottom" })
    )
    vim.list_extend(candidates, vim.tbl_map(function(x) return "ask=" .. x end, { "true", "false" }))
    return candidates
  end,
})
cmd("Chat", function() require("avante.api").ask({ ask = false }) end, { desc = "avante: chat with the codebase" })
cmd("Toggle", function() require("avante").toggle() end, { desc = "avante: toggle AI panel" })
cmd("Build", function(opts)
  local args = {}
  for _, arg in ipairs(opts.fargs) do
    local key, value = arg:match("(%w+)=(%w+)")
    if key and value then args[key] = value == "true" end
  end
  if args.source == nil then args.source = false end

  require("avante.api").build(args)
end, {
  desc = "avante: build dependencies",
  nargs = "*",
  complete = function(_, _, _) return { "source=true", "source=false" } end,
})
cmd(
  "Edit",
  function(opts) require("avante.api").edit(vim.trim(opts.args)) end,
  { desc = "avante: edit selected block", nargs = "*" }
)
cmd("Refresh", function() require("avante.api").refresh() end, { desc = "avante: refresh windows" })
cmd("Focus", function() require("avante.api").focus() end, { desc = "avante: switch focus windows" })
cmd("SwitchProvider", function(opts) require("avante.api").switch_provider(vim.trim(opts.args or "")) end, {
  nargs = 1,
  desc = "avante: switch provider",
  complete = function(_, line, _)
    local prefix = line:match("AvanteSwitchProvider%s*(.*)$") or ""
    ---@param key string
    return vim.tbl_filter(function(key) return key:find(prefix, 1, true) == 1 end, Config.providers)
  end,
})
cmd(
  "SwitchFileSelectorProvider",
  function(opts) require("avante.api").switch_file_selector_provider(vim.trim(opts.args or "")) end,
  {
    nargs = 1,
    desc = "avante: switch file selector provider",
  }
)
cmd("Clear", function(opts)
  local arg = vim.trim(opts.args or "")
  arg = arg == "" and "history" or arg
  if arg == "history" or arg == "memory" then
    local sidebar = require("avante").get()
    if not sidebar then
      Utils.error("No sidebar found")
      return
    end
    if arg == "history" then
      -- 强制清除历史文件
      local P = require("avante.path")
      if P.history_path:exists() then
        -- 使用更强力的方式删除历史目录
        local success, err = pcall(function()
          P.history_path:rm({ recursive = true })
          -- 确保目录被删除后再重新创建
          vim.cmd("sleep 50m")
          if not P.history_path:exists() then
            P.history_path:mkdir({ parents = true })
          end
          -- 清除历史文件缓存
          require("avante.path").clear_history_cache()
        end)
        
        if not success then
          Utils.error("清除历史记录失败: " .. tostring(err))
          return
        end
      end
      
      -- 强制清除当前会话历史
      if sidebar then
        sidebar:clear_history()
      end
      
      -- 强制刷新UI
      vim.cmd("redraw!")
      Utils.info("历史记录已清除")
    else
      sidebar:reset_memory()
      -- 强制刷新UI
      vim.cmd("redraw!")
      Utils.info("记忆已重置")
    end
  elseif arg == "cache" then
    local P = require("avante.path")
    -- 强制执行清除，不询问确认
    P.clear()
    vim.cmd("redraw!")
    Utils.info("缓存和历史记录已清除")
  else
    Utils.error("Invalid argument. Valid arguments: 'history', 'memory', 'cache'")
    return
  end
end, {
  desc = "avante: clear history, memory or cache",
  nargs = "?",
  complete = function(_, _, _) return { "history", "memory", "cache" } end,
})
cmd("ShowRepoMap", function() require("avante.repo_map").show() end, { desc = "avante: show repo map" })

-- 添加AvanteClear命令作为AvanteClean history的快捷方式
vim.api.nvim_create_user_command("AvanteClear", function()
  -- 直接调用AvanteClean history
  local sidebar = require("avante").get()
  if not sidebar then
    Utils.error("No sidebar found")
    return
  end
  
  -- 强制清除历史文件
  local P = require("avante.path")
  if P.history_path:exists() then
    -- 使用更强力的方式删除历史目录
    local success, err = pcall(function()
      P.history_path:rm({ recursive = true })
      -- 确保目录被删除后再重新创建
      vim.cmd("sleep 50m")
      if not P.history_path:exists() then
        P.history_path:mkdir({ parents = true })
      end
      -- 清除历史文件缓存
      require("avante.path").clear_history_cache()
    end)
    
    if not success then
      Utils.error("清除历史记录失败: " .. tostring(err))
      return
    end
  end
  
  -- 强制清除当前会话历史
  if sidebar then
    sidebar:clear_history()
  end
  
  -- 强制刷新UI
  vim.cmd("redraw!")
  Utils.info("历史记录已清除")
end, { desc = "avante: clear chat history (shortcut for AvanteClean history)" })

-- 添加禁用工具的命令
vim.api.nvim_create_user_command("AvanteDisableTools", function()
  require("avante.disable_tools")
end, {
  desc = "禁用所有Avante工具功能"
})

-- 添加启用工具的命令
vim.api.nvim_create_user_command("AvanteEnableTools", function()
  local disable_tools = require("avante.disable_tools")
  disable_tools.enable_tools()
end, {
  desc = "启用Avante工具功能"
})
