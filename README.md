# IO-QUIL 管理器
>> 运行前确保已经下载好Quilibrium以及IO运行正常(主要针对Mac用户)

IO-QUIL 管理器是一个用于自动化管理 IO 和 QUIL 进程的 Bash 脚本。它能够根据 Docker 容器的启动和停止事件来智能控制 QUIL 进程的运行状态。

## 功能

- 监控指定的 Docker 镜像事件
- 根据 PoW (Proof of Work) 容器的状态自动启动或停止 QUIL 进程
- 提供详细的操作日志
- 支持通过命令行参数和环境变量进行配置

## 依赖

- Bash (4.0+)
- Docker

## 安装

1. 克隆仓库：

```bash
git clone https://github.com/Zephyrsailor/io-quil-manager.git
```

2. 进入项目目录：
```
cd io-quil-manager
```

3. 为脚本添加执行权限：
```
chmod +x io_quil_manager.sh
```

## 使用方法
### 基本用法
```
./io_quil_manager.sh
```

### 使用命令行参数
```
./io_quil_manager.sh -p "process_name" -d "/path/to/quil" -c "./quil_command" -l "/path/to/log"
```

参数说明：

- p: QUIL 进程名称
- d: QUIL 程序所在目录
- c: 启动 QUIL 的命令
- l: 日志文件路径

### 使用环境变量
```
# 默认 node-1.4.21-darwin-arm64
export QUIL_PROCESS_NAME="process_name"
# 默认 ~/ceremonyclient/node
export QUIL_DIR="/path/to/quil"
# 默认 ./node-1.4.21-darwin-arm64
export QUIL_COMMAND="./quil_command"
# 默认 /tmp/quil.log
export QUIL_LOG="/path/to/log"
./io_quil_manager.sh
```

## 配置
### 脚本使用以下配置项：

- QUIL_PROCESS_NAME: QUIL 进程的名称
- QUIL_DIR: QUIL 程序所在的目录
- QUIL_COMMAND: 启动 QUIL 的命令
- QUIL_LOG: 日志文件路径
- IO_IMAGES: 需要监控的 IO 镜像列表
- POW_IMAGE: PoW 镜像名称

## 联系方式
如有任何问题或建议，请开设一个 issue 或直接联系项目维护者。
