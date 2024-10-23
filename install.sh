#!/bin/zsh
SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
cd "$SCRIPTPATH"

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印带颜色的消息
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要的命令是否存在
check_dependencies() {
    local missing_deps=()

    for cmd in git curl make cargo nvim; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install them first"
        exit 1
    fi
}

# 创建必要的目录
create_directories() {
    log_info "Creating necessary directories..."

    mkdir -p ~/.config/nvim
    mkdir -p ~/.vim/plugin
    mkdir -p ~/loadrc/avante.nvim
}

# 建立符号链接
create_symlinks() {
    log_info "Creating symlinks..."

    # 使用提供的 ln_fs.sh 脚本创建符号链接
    ~/loadrc/bashrc/ln_fs.sh ./.vimrc ~/.vimrc || true
    ~/loadrc/bashrc/ln_fs.sh ./.config/nvim/init.lua ~/.config/nvim/init.lua || true
}

# 安装 lazy.nvim
install_lazy_nvim() {
    log_info "Installing lazy.nvim..."

    local lazypath="$HOME/.local/share/nvim/lazy/lazy.nvim"
    if [ ! -d "$lazypath" ]; then
        git clone --filter=blob:none https://github.com/folke/lazy.nvim.git \
            --branch=stable "$lazypath"
    fi
}

# 构建 avante.nvim
build_avante() {
    log_info "Building avante.nvim..."

    cd ~/loadrc/avante.nvim

    # 检查是否需要从源码构建
    if [ "$BUILD_FROM_SOURCE" = "true" ]; then
        make clean
        make BUILD_FROM_SOURCE=true
    else
        # 使用预编译的二进制文件
        bash ./build.sh
    fi
}

# 主函数
main() {
    log_info "Starting installation..."

    # 检查依赖
    check_dependencies

    # 创建目录
    create_directories

    # 创建符号链接
    create_symlinks

    # 安装 lazy.nvim
    install_lazy_nvim

    # 构建 avante.nvim
    build_avante

    log_info "Installation completed successfully!"
    log_info "Please restart Neovim to apply changes."
}

# 执行主函数
main "$@"
