#!/bin/bash
set -e

# 主菜单
while true; do
    clear
    echo "============== SSL证书管理菜单 =============="
    echo "1) 申请 SSL 证书"
    echo "2) 重置环境（清除申请记录并重新部署）"
    echo "3) 退出"
    echo "============================================"
    read -p "请输入选项（1-3）： " MAIN_OPTION

    case $MAIN_OPTION in
        1) break ;;
        2)
            echo "⚠️ 正在重置环境..."
            rm -rf ~/.acme.sh
            echo "✅ 已清空本地 acme 环境。"
            exit 0
            ;;
        3)
            echo "👋 已退出。"
            exit 0
            ;;
        *)
            echo "❌ 无效选项，请重新输入。"
            sleep 1
            continue
            ;;
    esac
done

# 用户输入参数
read -p "请输入要申请证书的域名: " DOMAIN
read -p "请输入您的电子邮件地址: " EMAIL

echo "请选择证书颁发机构（CA）："
echo "1) Let's Encrypt (推荐)"
echo "2) Buypass"
echo "3) ZeroSSL"
read -p "输入选项（1-3）： " CA_OPTION
case $CA_OPTION in
    1) CA_SERVER="letsencrypt" ;;
    2) CA_SERVER="buypass" ;;
    3) CA_SERVER="zerossl" ;;
    *) echo "❌ 无效选项"; exit 1 ;;
esac

echo "======================================================"
echo "⚠️  注意：当前采用 Standalone 模式申请证书！"
echo "⚠️  请务必确保：云服务商(如阿里云/腾讯云)的安全组已放行 80 端口！"
echo "⚠️  并且本机没有运行 Nginx/Apache 等占用 80 端口的程序！"
echo "======================================================"
read -p "确认 80 端口已放行并空闲？(y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "已取消申请，请放行 80 端口后再来。"
    exit 1
fi

# 检查系统类型并安装依赖
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "❌ 无法识别操作系统，请手动安装依赖。"
    exit 1
fi

# 自动处理内部防火墙和依赖
case $OS in
    ubuntu|debian)
        sudo apt update -y
        sudo apt install -y curl socat git cron
        if command -v ufw >/dev/null 2>&1; then
            sudo ufw allow 80/tcp
            sudo ufw allow 443/tcp
        fi
        ;;
    centos|rocky|almalinux)
        sudo yum update -y || sudo dnf update -y
        sudo yum install -y curl socat git cronie || sudo dnf install -y curl socat git cronie
        sudo systemctl start crond && sudo systemctl enable crond
        if command -v firewall-cmd >/dev/null 2>&1; then
            sudo firewall-cmd --permanent --add-port=80/tcp
            sudo firewall-cmd --permanent --add-port=443/tcp
            sudo firewall-cmd --reload
        fi
        ;;
    *)
        echo "❌ 不支持的操作系统：$OS"
        exit 1
        ;;
esac

# 安装 acme.sh（更精准的判断）
if [ ! -f "$HOME/.acme.sh/acme.sh" ]; then
    echo "📦 正在安装 acme.sh..."
    curl https://get.acme.sh | sh
fi

# 设置 acme.sh 别名和环境
ACME_SH="$HOME/.acme.sh/acme.sh"

# 升级并设置默认 CA
$ACME_SH --upgrade
$ACME_SH --set-default-ca --server $CA_SERVER

# 注册账户
$ACME_SH --register-account -m "$EMAIL"

# 申请证书 (Standalone)
echo "🚀 开始申请证书..."
if ! $ACME_SH --issue --standalone -d "$DOMAIN"; then
    echo "❌ 证书申请失败！极大概率是 80 端口未对外开放，请检查云服务商安全组！"
    $ACME_SH --remove -d "$DOMAIN"
    exit 1
fi

# 安装证书 (acme.sh 会自动记住这个路径用于后续自动续期)
echo "📦 正在安装证书到 /root 目录..."
$ACME_SH --installcert -d "$DOMAIN" \
    --key-file       /root/${DOMAIN}.key \
    --fullchain-file /root/${DOMAIN}.crt

# 完成提示 (去除了自己画蛇添足的 cronjob，因为 acme.sh 已经搞定了)
echo "=========================================="
echo "✅ SSL证书申请并安装完成！"
echo "📄 证书路径: /root/${DOMAIN}.crt"
echo "🔐 私钥路径: /root/${DOMAIN}.key"
echo "⏳ acme.sh 已自动配置好定时任务，证书将在到期前自动续期。"
echo "=========================================="
