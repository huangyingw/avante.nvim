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
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# 安装 Rust 和 Cargo
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

# 安装 avante.nvim 并编译
RUN nvim --headless -c "lua require('lazy').sync()" -c "qa"
RUN cd /root/.local/share/nvim/lazy/avante.nvim && make

# 安装 Lua 和 LuaJIT
RUN apt-get update && apt-get install -y \
    lua5.1 \
    liblua5.1-0-dev \
    luajit \
    libluajit-5.1-dev \
    && rm -rf /var/lib/apt/lists/*

# 设置 Lua 和 LuaJIT 的环境变量
ENV LUA_PATH="/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua"
ENV LUA_CPATH="/usr/local/lib/lua/5.1/?.so;/usr/lib/x86_64-linux-gnu/lua/5.1/?.so;/usr/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so"
ENV PATH="/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games:/snap/bin:/root/.cargo/bin"

# 添加调试信息
RUN ls -la /root/.local/share/nvim/lazy/avante.nvim
RUN ls -la /root/.local/share/nvim/lazy/avante.nvim/lua/avante

# 尝试手动编译 avante_repo_map
RUN cd /root/.local/share/nvim/lazy/avante.nvim && \
    cargo clean && \
    cargo build --release --features luajit && \
    ls -l target/release/ && \
    cp target/release/libavante_repo_map.so lua/avante/avante_repo_map.so && \
    ls -l lua/avante/

# 设置环境变量
ENV LD_LIBRARY_PATH=/root/.local/share/nvim/lazy/avante.nvim/lua/avante:$LD_LIBRARY_PATH
ENV LUA_CPATH="/root/.local/share/nvim/lazy/avante.nvim/lua/avante/?.so;${LUA_CPATH}"

# 编辑 Cargo.toml 文件，只启用 luajit 特性
RUN sed -i 's/^features = .*/features = ["luajit"]/' /root/.local/share/nvim/lazy/avante.nvim/Cargo.toml

# 对于 crates/avante-repo-map/Cargo.toml 文件也进行同样的修改
RUN sed -i 's/^features = .*/features = ["luajit"]/' /root/.local/share/nvim/lazy/avante.nvim/crates/avante-repo-map/Cargo.toml

ENV LUA_VERSION=luajit

# 添加调试命令
RUN echo $LUA_CPATH
RUN cat /root/.local/share/nvim/lazy/avante.nvim/Cargo.toml

CMD ["nvim"]
