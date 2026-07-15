#!/bin/bash
set -e

# ========= 检查并安装 git =========
echo "🔍 正在检查 git 是否已安装..."
if ! command -v git >/dev/null 2>&1; then
    echo "⚠️ 未检测到 git，正在尝试安装..."

    # 智能处理 sudo：如果是 root 用户，则不使用 sudo
    SUDO_CMD=""
    if [ "$EUID" -ne 0 ]; then
        if ! command -v sudo >/dev/null 2>&1; then
            echo "❌ 当前不是 root 用户，且未安装 sudo，无法安装依赖，请使用 root 运行。"
            exit 1
        fi
        SUDO_CMD="sudo"
    fi

    # 判断系统类型
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$ID
    else
        OS_ID=$(uname -s)
    fi

    if [[ "$OS_ID" == "debian" || "$OS_ID" == "ubuntu" ]]; then
        $SUDO_CMD apt update -y
        $SUDO_CMD apt install git -y || {
            echo "❌ git 安装失败，请检查网络。"
            exit 1
        }
    elif [[ "$OS_ID" == "centos" || "$OS_ID" == "rocky" || "$OS_ID" == "almalinux" ]]; then
        $SUDO_CMD yum update -y || $SUDO_CMD dnf update -y
        $SUDO_CMD yum install git -y || $SUDO_CMD dnf install git -y || {
            echo "❌ git 安装失败，请检查网络。"
            exit 1
        }
    else
        echo "❌ 无法识别的系统类型，请手动安装 git。"
        exit 1
    fi
else
    echo "✅ git 已安装。"
fi

# ========= 清理旧目录并克隆新项目 =========
echo "🔍 正在下载证书申请脚本..."
# 将项目克隆到一个独立的文件夹，避免污染 /root 根目录
WORK_DIR="/root/SSL-Renewal"
rm -rf "$WORK_DIR"

git clone https://github.com/meiao123/SSL-Renewal.git "$WORK_DIR"

# 赋予执行权限并运行
echo "🚀 开始运行证书申请脚本..."
chmod +x "$WORK_DIR/acme_3.0.sh"

# 进入目录后执行，避免相对路径报错
cd "$WORK_DIR"
script -q -c "./acme_3.0.sh" /dev/null

echo "✅ 自动化脚本执行完毕！"
