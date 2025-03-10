#!/bin/bash

# 检查是否以root权限运行
if [ "$(id -u)" != "0" ]; then
    echo "此脚本必须以root权限运行" 1>&2
    exit 1
fi

# 变量声明
USER="game"
SCREEN_NAME="s6"
WORK_DIR="/home/game/server_6"
START_SCRIPT="./DragonsServer.sh"
PORT="7782"
QUERYPORT="7020"
SERVER_NAME="[宁波] New Dawn #6"
LOG_FILE="/home/game/server_6/Dragons/Saved/Logs/Dragons.log"
FAIL_MESSAGE="LogOnline: Warning: OSS: Async task 'FOnlineAsyncTaskSteamCreateServer bWasSuccessful: 0' failed in"
SUCCESS_MESSAGE="AutoSave timer started. Saving every 300.0 seconds!"
SCREEN_QUIT_WAIT_TIME=10
START_WAIT_TIME=5
SUCCESS_FLAG_FILE="/tmp/dragons_success_flag"

# 函数：清理screen会话及其相关进程
cleanup_screen() {
    echo "正在清理 '$SCREEN_NAME' screen会话及其进程..."
    # 获取screen会话的PID
    SCREEN_PID=$(sudo -u "$USER" screen -ls | grep "$SCREEN_NAME" | awk '{print $1}' | cut -d'.' -f1)
    
    if [ -n "$SCREEN_PID" ]; then
        # 首先尝试正常退出screen
        sudo -u "$USER" screen -S "$SCREEN_NAME" -X quit
        sleep 2  # 短暂等待
        
        # 检查screen是否还存在
        if sudo -u "$USER" screen -ls | grep -q "$SCREEN_NAME"; then
            # 如果screen还在，强制杀死screen进程
            kill -9 "$SCREEN_PID" 2>/dev/null
        fi
    fi
    
    # 查找并杀死工作目录下可能残留的相关进程
    pids=$(pgrep -u "$USER" -f "$WORK_DIR")
    if [ -n "$pids" ]; then
        echo "发现残留进程，PID: $pids"
        kill -9 $pids 2>/dev/null
    fi
    
    sleep "$SCREEN_QUIT_WAIT_TIME"
}

# 清理可能的旧标志文件
rm -f "$SUCCESS_FLAG_FILE"

# 确保日志文件目录存在
mkdir -p "$(dirname "$LOG_FILE")"
chown "$USER" "$(dirname "$LOG_FILE")"

# 主循环
while true; do
    # 清理现有会话
    cleanup_screen
    
    echo "正在启动新的 '$SCREEN_NAME' screen会话..."
    # 创建新的screen会话并记录PID
    sudo -u "$USER" screen -dmS "$SCREEN_NAME" sh -c "cd $WORK_DIR && $START_SCRIPT ?Port=$PORT ?QueryPort=$QUERYPORT -SteamServerName=\"$SERVER_NAME\" -log"
    
    sleep "$START_WAIT_TIME"
    echo "开始监控日志文件: $LOG_FILE"
    
    # 监控日志并设置超时（比如60秒）
    timeout 60 tail -f "$LOG_FILE" | while read line; do
        echo "日志行: $line"
        if echo "$line" | grep -q "$FAIL_MESSAGE"; then
            echo "检测到启动失败: $FAIL_MESSAGE"
            break
        elif echo "$line" | grep -q "$SUCCESS_MESSAGE"; then
            echo "检测到启动成功: $SUCCESS_MESSAGE"
            touch "$SUCCESS_FLAG_FILE"
            break
        fi
    done

    if [ -f "$SUCCESS_FLAG_FILE" ]; then
        echo "服务器启动成功，脚本退出。"
        rm -f "$SUCCESS_FLAG_FILE"
        exit 0
    fi
    
    echo "未检测到成功启动，重新尝试..."
done
