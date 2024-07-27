#!/bin/bash

set -e

# 默认配置
DEFAULT_QUIL_PROCESS_NAME="node-1.4.21-darwin-arm64"
DEFAULT_QUIL_DIR="~/ceremonyclient/node"
DEFAULT_QUIL_COMMAND="./node-1.4.21-darwin-arm64"
DEFAULT_QUIL_LOG="/tmp/quil.log"

# 解析命令行参数
while getopts ":p:d:c:l:" opt; do
  case $opt in
    p) QUIL_PROCESS_NAME="$OPTARG" ;;
    d) QUIL_DIR="$OPTARG" ;;
    c) QUIL_COMMAND="$OPTARG" ;;
    l) QUIL_LOG="$OPTARG" ;;
    \?) echo "无效选项: -$OPTARG" >&2; exit 1 ;;
    :) echo "选项 -$OPTARG 需要参数." >&2; exit 1 ;;
  esac
done

# 使用环境变量或默认值设置配置
QUIL_PROCESS_NAME="${QUIL_PROCESS_NAME:-$DEFAULT_QUIL_PROCESS_NAME}"
QUIL_DIR="${QUIL_DIR:-$DEFAULT_QUIL_DIR}"
QUIL_COMMAND="${QUIL_COMMAND:-$DEFAULT_QUIL_COMMAND}"
QUIL_LOG="${QUIL_LOG:-$DEFAULT_QUIL_LOG}"

# IO 和 POW 镜像配置
IO_IMAGES=("ionetcontainers/io-worker-vc" "ionetcontainers/io-launch:v0.1")
POW_IMAGE="ionetcontainers/io-service-ray"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$QUIL_LOG"
}

# 错误日志函数
error_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 错误: $1" | tee -a "$QUIL_LOG" >&2
}

# 停止 Quil 进程
stop_quil() {
    log "尝试停止 Quil 进程 (进程名: $QUIL_PROCESS_NAME)"
    if pgrep -f "$QUIL_PROCESS_NAME" > /dev/null; then
        pkill -TERM -f "$QUIL_PROCESS_NAME"
        sleep 5
        if pgrep -f "$QUIL_PROCESS_NAME" > /dev/null; then
            log "警告: Quil 进程未能正常停止，尝试强制终止"
            pkill -KILL -f "$QUIL_PROCESS_NAME"
        fi
        log "Quil 进程已停止"
    else
        log "Quil 进程未运行，无需停止"
    fi
}

# 启动 Quil 进程
start_quil() {
    if ! pgrep -f "$QUIL_PROCESS_NAME" > /dev/null; then
        log "尝试启动 Quil 进程"
        log "Quil 目录: $QUIL_DIR"
        log "Quil 命令: $QUIL_COMMAND"
        if [ ! -d "$QUIL_DIR" ]; then
            error_log "无法进入 Quil 目录，目录不存在: $QUIL_DIR"
            exit 1
        fi
        cd "$QUIL_DIR" || { error_log "无法进入 Quil 目录: $QUIL_DIR"; exit 1; }
        if [ ! -x "$QUIL_COMMAND" ]; then
            error_log "Quil 命令不存在或没有执行权限: $QUIL_COMMAND"
            exit 1
        fi
        $QUIL_COMMAND >> "$QUIL_LOG" 2>&1 &
        sleep 5
        if pgrep -f "$QUIL_PROCESS_NAME" > /dev/null; then
            log "Quil 进程已成功启动"
        else
            error_log "Quil 进程启动失败。请检查日志文件: $QUIL_LOG"
            exit 1
        fi
    else
        log "Quil 进程已在运行"
    fi
}

# 检查是否有正在运行的 PoW 容器
check_running_pow() {
    docker ps --format '{{.Image}}' | grep -q "$POW_IMAGE"
}

# 主程序
main() {
    # 在脚本启动时检查 PoW 容器
    if check_running_pow; then
        log "检测到正在运行的 PoW 容器，停止 Quil 进程"
        stop_quil
    else
        log "没有检测到正在运行的 PoW 容器，启动 Quil 进程"
        start_quil
    fi

    # 构建 Docker 事件过滤器
    FILTER=""
    for image in "${IO_IMAGES[@]}"; do
        FILTER="$FILTER --filter image=$image"
    done
    FILTER="$FILTER --filter image=$POW_IMAGE"

    # 监听 Docker 事件
    log "开始监听 Docker 事件"
    docker events --filter 'type=container' $FILTER --format '{{.Status}} {{.ID}} {{.From}}' | while read event container_id image
    do
        container_name=$(docker inspect --format '{{.Name}}' "$container_id" | sed 's/^.\{1\}//')
        log "检测到容器事件: $event $container_id $image (容器名称: $container_name)"
        
        # 只处理我们关心的事件类型
        if [[ $event == "start" && "$image" == *"$POW_IMAGE"* ]]; then
            log "检测到 PoW 镜像 $image 的容器 $container_id 启动，停止 Quil 进程"
            stop_quil
            log "正在等待 PoW 容器 $container_id 结束"
            docker wait "$container_id" > /dev/null
            log "PoW 容器 $container_id 已结束"
            start_quil
        elif [[ $event == "die" && "$image" == *"$POW_IMAGE"* ]]; then
            log "检测到容器 $container_id 停止事件: $event $image (容器名称: $container_name)"
            log "PoW 容器 $container_id 已停止"
            start_quil
        fi
    done
}

# 捕获 SIGINT 信号
trap 'log "收到中断信号，正在退出..."; exit 0' SIGINT

# 运行主程序
main