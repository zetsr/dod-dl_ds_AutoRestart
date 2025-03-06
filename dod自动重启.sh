#!/bin/bash

# 检查是否以root权限运行
if [ "$(id -u)" != "0" ]; then
    echo "此脚本必须以root权限运行" 1>&2
    exit 1
fi

# 变量声明
USER="YourUserName"                              # 执行命令的用户
SCREEN_NAME="dod"                    # screen会话名称
WORK_DIR="/home/game/Steam/steamapps/common/dod_server"  # 工作目录
START_SCRIPT="./DragonsServer.sh"  # 启动脚本路径
PORT="7777"                              # 启动端口
QUERYPORT="27015"                        # 查询端口
SERVER_NAME="YOUR SERVER NAME"  # 服务器名称
LOG_FILE="/home/game/Steam/steamapps/common/dod_server/Dragons/Saved/Logs/Dragons.log"  # 日志文件路径
FAIL_MESSAGE="LogOnline: Warning: OSS: Async task 'FOnlineAsyncTaskSteamCreateServer bWasSuccessful: 0' failed in"  # 失败日志关键字
SUCCESS_MESSAGE="AutoSave timer started. Saving every 300.0 seconds!"  # 成功日志关键字（部分匹配）
SCREEN_QUIT_WAIT_TIME=3                 # 等待screen结束的时间（秒）
START_WAIT_TIME=1                        # 启动服务端后等待的时间（秒）
SUCCESS_FLAG_FILE="/tmp/dragons_success_flag"  # 成功标志文件路径

# 清理可能的旧标志文件
rm -f "$SUCCESS_FLAG_FILE"

# 进入无限循环，直到服务器启动成功
while true; do
    echo "正在结束现有的 '$SCREEN_NAME' screen会话..."
    # 结束现有的screen会话
    sudo -u "$USER" screen -S "$SCREEN_NAME" -X quit
    # 等待一段时间，确保会话已完全结束
    sleep "$SCREEN_QUIT_WAIT_TIME"
    echo "正在启动新的 '$SCREEN_NAME' screen会话..."
    # 创建新的screen会话并运行启动命令
    sudo -u "$USER" screen -dmS "$SCREEN_NAME" sh -c "cd $WORK_DIR && $START_SCRIPT ?Port=$PORT ?QueryPort=$QUERYPORT -SteamServerName=\"$SERVER_NAME\" -log"
    # 启动后等待一段时间，确保服务端开始生成日志
    sleep "$START_WAIT_TIME"
    echo "开始监控日志文件: $LOG_FILE"
    # 实时监控日志文件
    tail -f "$LOG_FILE" | while read line; do
        echo "日志行: $line"  # 调试：输出每行日志
        # 检查日志是否包含失败关键字
        if echo "$line" | grep -q "$FAIL_MESSAGE"; then
            echo "检测到启动失败: $FAIL_MESSAGE"
            # 启动失败，跳出监控循环，重新开始整个流程
            break
        # 检查日志是否包含成功关键字
        elif echo "$line" | grep -q "$SUCCESS_MESSAGE"; then
            echo "检测到启动成功: $SUCCESS_MESSAGE"
            # 创建成功标志文件
            touch "$SUCCESS_FLAG_FILE"
            # 退出内层循环
            break
        fi
    done

    # 检查是否创建了成功标志文件
    if [ -f "$SUCCESS_FLAG_FILE" ]; then
        echo "服务器启动成功，脚本退出。"
        rm -f "$SUCCESS_FLAG_FILE"  # 清理标志文件
        exit 0
    fi
    # 如果没有成功标志，继续下一次循环（启动失败或未检测到成功）
    echo "未检测到成功启动，重新尝试..."
done