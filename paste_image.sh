#!/bin/bash

# Avante Image Paste Tool
# 用于从命令行粘贴图片到Avante Neovim插件

# 确保目录存在
PASTE_DIR="$HOME/.cache/avante/pasted_images"
mkdir -p "$PASTE_DIR"

# 生成唯一的文件名
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
RANDOM_NUM=$((RANDOM % 900000 + 100000))
IMAGE_PATH="$PASTE_DIR/${TIMESTAMP}_${RANDOM_NUM}.png"

# 检查pngpaste是否安装
if ! command -v pngpaste &> /dev/null; then
    echo "正在尝试安装pngpaste..."
    if command -v brew &> /dev/null; then
        brew install pngpaste
    else
        echo "无法找到pngpaste，无法安装Homebrew。请手动安装pngpaste。"
        exit 1
    fi
fi

# 尝试使用pngpaste保存图片
echo "尝试保存剪贴板中的图片..."
pngpaste "$IMAGE_PATH" 2>/dev/null

# 检查图片是否成功保存
if [ -f "$IMAGE_PATH" ] && [ $(stat -f%z "$IMAGE_PATH") -gt 100 ]; then
    echo "图片已成功保存到: $IMAGE_PATH"
    echo ""
    echo "image: $IMAGE_PATH"
    echo ""
    echo "请复制上面的'image:'行到Avante编辑器中"
    exit 0
fi

# 如果pngpaste失败，尝试使用AppleScript
echo "pngpaste失败，尝试使用AppleScript..."
osascript -e '
tell application "System Events" to ¬
    if the clipboard contains picture data then
        set the_picture to the clipboard as «class PNGf»
        set the_file to open for access (POSIX file "'"$IMAGE_PATH"'") with write permission
        write the_picture to the_file
        close access the_file
        return "success"
    else
        return "no picture"
    end if
'

# 检查AppleScript是否成功
if [ -f "$IMAGE_PATH" ] && [ $(stat -f%z "$IMAGE_PATH") -gt 100 ]; then
    echo "图片已成功保存到: $IMAGE_PATH"
    echo ""
    echo "image: $IMAGE_PATH"
    echo ""
    echo "请复制上面的'image:'行到Avante编辑器中"
    exit 0
fi

# 如果都失败了，检查剪贴板是否包含图片路径
CLIPBOARD=$(pbpaste)
if [[ "$CLIPBOARD" =~ \.(png|jpg|jpeg|gif|webp|bmp)$ ]]; then
    if [ -f "$CLIPBOARD" ]; then
        echo "检测到有效的图片路径: $CLIPBOARD"
        echo ""
        echo "image: $CLIPBOARD"
        echo ""
        echo "请复制上面的'image:'行到Avante编辑器中"
        exit 0
    fi
fi

# 如果所有方法都失败
echo "无法从剪贴板获取图片。确保已复制图片到剪贴板中。"
exit 1 