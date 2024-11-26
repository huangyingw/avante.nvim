#!/bin/zsh
SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
cd "$SCRIPTPATH"

# 定义变量
pname="cursor"
version="0.42.4"
appKey="230313mzl4w4u92"
url="https://dl.todesktop.com/${appKey}/versions/${version}/macos"

# 定义下载目标文件名
output_file="${pname}-${version}.dmg"

# 下载文件
echo "Downloading ${pname} version ${version}..."
curl -L -o "${output_file}" "${url}"

echo "Download and verification completed successfully."
