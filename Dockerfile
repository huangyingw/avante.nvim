FROM ubuntu:22.04

# 避免交互式前端
ENV DEBIAN_FRONTEND=noninteractive

# 设置时区
ENV TZ=Asia/Shanghai

# 安装必要的包
RUN apt-get update && apt-get install -y \
    git \
    nodejs \
    npm \
    curl \
    make \
    gcc \
    g++ \
    libc-dev \
    cmake \
    pkg-config \
    unzip \
    gettext \
    && rm -rf /var/lib/apt/lists/*

# 安装 Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# 安装最新版本的 Neovim
RUN git clone https://github.com/neovim/neovim.git /tmp/neovim \
    && cd /tmp/neovim \
    && make CMAKE_BUILD_TYPE=RelWithDebInfo \
    && make install \
    && rm -rf /tmp/neovim

# 设置 Neovim 配置目录
RUN mkdir -p /root/.config/nvim

# 安装 lazy.nvim（插件管理器）
RUN git clone --filter=blob:none https://github.com/folke/lazy.nvim.git \
    --branch=stable /root/.local/share/nvim/lazy/lazy.nvim

# 复制 Neovim 配置
COPY init.lua /root/.config/nvim/init.lua

# 设置工作目录
WORKDIR /root/workspace

# 清理不必要的包和缓存
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

CMD ["nvim"]
