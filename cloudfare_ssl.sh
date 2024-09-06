#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 调试模式
DEBUG=true

# ASCII 艺术字
echo -e "${PURPLE}"
cat << "EOF"
 __     __  ______  _____   _____     __     __  _____ 
 \ \   / / |  __  \|  __ \ |  __ \    \ \   / / |_   _|
  \ \_/ /  | |__) || |__) || |  | |    \ \_/ /    | |  
   \   /   |  ___/ |  _  / | |  | |     \   /     | |  
    | |    | |     | | \ \ | |__| |      | |     _| |_ 
    |_|    |_|     |_|  \_\|_____/       |_|    |_____|
                                                       
EOF
echo -e "${NC}"

# 配置文件路径
CONFIG_FILE="/etc/cloudflaressl.conf"

# 日志函数
log() {
    echo -e "${CYAN}[Yord YI] $(date '+%Y-%m-%d %H:%M:%S')${NC} ${2}${1}${NC}"
}

# 调试输出函数
debug_log() {
    if [ "$DEBUG" = true ]; then
        echo -e "${BLUE}[DEBUG] $1${NC}"
    fi
}

# 错误处理函数
error_exit() {
    log "$1" "${RED}"
    exit 1
}

# 清理函数
cleanup() {
    log "执行清理操作..." "${BLUE}"
    # 在这里添加任何需要的清理操作
}

# 捕获脚本退出信号
trap cleanup EXIT

# 检查命令是否可用
check_command() {
    command -v "$1" >/dev/null 2>&1 || error_exit "需要 $1 命令，但它没有安装。请安装后再运行此脚本。"
}

# 检查必要的命令
check_command curl
check_command jq
check_command openssl

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    error_exit "请以 root 权限运行此脚本"
fi

# 解析命令行参数
while getopts ":e:k:d:s:c" opt; do
    case ${opt} in
        e ) CF_Email=$OPTARG ;;
        k ) CF_Key=$OPTARG ;;
        d ) DOMAIN=$OPTARG ;;
        s ) SUBDOMAIN=$OPTARG ;;
        c ) USE_CONFIG=1 ;;
        \? ) error_exit "无效选项: -$OPTARG" ;;
        : ) error_exit "选项 -$OPTARG 需要一个参数" ;;
    esac
done

# 如果指定使用配置文件，则从配置文件读取
if [ "$USE_CONFIG" = "1" ]; then
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        error_exit "配置文件 $CONFIG_FILE 不存在"
    fi
fi

# 如果还有未设置的变量，则提示用户输入
[ -z "$CF_Email" ] && read -p "$(echo -e ${YELLOW}"请输入 Cloudflare 邮箱: "${NC})" CF_Email
[ -z "$CF_Key" ] && read -p "$(echo -e ${YELLOW}"请输入 Cloudflare API 密钥: "${NC})" CF_Key
[ -z "$DOMAIN" ] && read -p "$(echo -e ${YELLOW}"请输入主域名: "${NC})" DOMAIN

# 函数：获取二级域名输入
get_subdomain() {
    read -p "$(echo -e ${YELLOW}"请输入二级域名 (不包括主域名部分): "${NC})" SUBDOMAIN
    FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"
}

# 初始获取二级域名
get_subdomain

# 保存配置到文件
save_config() {
    cat > "$CONFIG_FILE" << EOF
CF_Email="$CF_Email"
CF_Key="$CF_Key"
DOMAIN="$DOMAIN"
SUBDOMAIN="$SUBDOMAIN"
EOF
    chmod 600 "$CONFIG_FILE"
    log "配置已保存到 $CONFIG_FILE" "${GREEN}"
}

# 询问用户是否保存配置
read -p "$(echo -e ${YELLOW}"是否保存配置以便下次使用? (y/n): "${NC})" save_choice
if [[ $save_choice =~ ^[Yy]$ ]]; then
    save_config
fi

# 安装必要的软件
for pkg in socat jq curl; do
    if ! command -v $pkg &> /dev/null; then
        log "正在安装 $pkg..." "${BLUE}"
        apt-get update && apt-get install -y $pkg || error_exit "安装 $pkg 失败"
    fi
done

# 检查并安装 acme.sh
install_acme() {
    log "正在安装 acme.sh..." "${BLUE}"
    curl https://get.acme.sh | sh -s email=$CF_Email || error_exit "安装 acme.sh 失败"
    source ~/.bashrc
}

# 检查 acme.sh 是否已安装
ACME_SH="/root/.acme.sh/acme.sh"
HIDDIFY_ACME="/opt/hiddify-manager/acme.sh/lib/acme.sh"

if [ -f "$ACME_SH" ]; then
    log "acme.sh 已安装在 $ACME_SH" "${GREEN}"
elif [ -f "$HIDDIFY_ACME" ]; then
    log "acme.sh 已安装在 $HIDDIFY_ACME" "${BLUE}"
    mkdir -p /root/.acme.sh
    ln -sf "$HIDDIFY_ACME" "$ACME_SH"
    if [ -f "$ACME_SH" ]; then
        log "已创建符号链接到 $ACME_SH" "${GREEN}"
    else
        log "创建符号链接失败，尝试复制文件" "${YELLOW}"
        cp "$HIDDIFY_ACME" "$ACME_SH" || error_exit "复制 acme.sh 失败"
        log "已复制 acme.sh 到 $ACME_SH" "${GREEN}"
    fi
else
    install_acme
fi

# 确保 acme.sh 是可执行的
chmod +x "$ACME_SH"

# 配置 Cloudflare API
export CF_Email
export CF_Key

# 获取 Zone ID
log "正在获取 Zone ID..." "${BLUE}"
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
     -H "X-Auth-Email: $CF_Email" \
     -H "X-Auth-Key: $CF_Key" \
     -H "Content-Type: application/json" | jq -r '.result[0].id')

debug_log "获取到的 Zone ID: $ZONE_ID"

[ -z "$ZONE_ID" ] && error_exit "无法获取 Zone ID，请检查域名和 API 凭证。"

# 获取服务器 IP
SERVER_IP=$(curl -s ifconfig.me)
log "服务器 IP: $SERVER_IP" "${GREEN}"

# 创建或更新 A 记录
while true; do
    log "正在检查 A 记录..." "${BLUE}"

    # 检查记录是否已存在
    debug_log "检查 A 记录是否存在..."
    EXISTING_RECORD=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$FULL_DOMAIN" \
         -H "X-Auth-Email: $CF_Email" \
         -H "X-Auth-Key: $CF_Key" \
         -H "Content-Type: application/json")

    debug_log "API 响应: $EXISTING_RECORD"

    RECORD_ID=$(echo $EXISTING_RECORD | jq -r '.result[0].id')
    
    if [ "$RECORD_ID" != "null" ] && [ -n "$RECORD_ID" ]; then
        log "A 记录 $FULL_DOMAIN 已存在。" "${YELLOW}"
        read -p "$(echo -e ${YELLOW}"是否重新输入二级域名? (y/n): "${NC})" retry_choice
        if [[ $retry_choice =~ ^[Yy]$ ]]; then
            get_subdomain
            continue
        else
            error_exit "A 记录已存在，脚本退出。"
        fi
    else
        # 记录不存在，创建新记录
        log "正在创建 A 记录..." "${BLUE}"
        RECORD_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
             -H "X-Auth-Email: $CF_Email" \
             -H "X-Auth-Key: $CF_Key" \
             -H "Content-Type: application/json" \
             --data "{\"type\":\"A\",\"name\":\"$FULL_DOMAIN\",\"content\":\"$SERVER_IP\",\"ttl\":1,\"proxied\":false}")
        
        if echo "$RECORD_RESPONSE" | jq -e '.success' &>/dev/null; then
            log "A 记录创建成功" "${GREEN}"
            break
        else
            error_exit "A 记录创建失败。错误信息：\n$(echo "$RECORD_RESPONSE" | jq '.errors')"
        fi
    fi
done

# 生成证书
log "正在生成证书..." "${BLUE}"
"$ACME_SH" --issue --dns dns_cf -d $FULL_DOMAIN || error_exit "生成证书失败"

# 创建证书目录
mkdir -p /etc/nginx/ssl

# 安装证书到指定路径
log "正在安装证书..." "${BLUE}"
"$ACME_SH" --install-cert -d $FULL_DOMAIN \
    --key-file /etc/nginx/ssl/$FULL_DOMAIN.key  \
    --fullchain-file /etc/nginx/ssl/$FULL_DOMAIN.crt || error_exit "安装证书失败"

# 配置自动更新
log "配置证书自动更新..." "${BLUE}"
"$ACME_SH" --upgrade --auto-upgrade || log "配置自动更新失败，请手动检查" "${YELLOW}"

# 输出证书路径和完整的域名
log "证书生成和安装成功！" "${GREEN}"
log "证书路径：" "${GREEN}"
log "密钥文件：/etc/nginx/ssl/$FULL_DOMAIN.key" "${GREEN}"
log "证书文件：/etc/nginx/ssl/$FULL_DOMAIN.crt" "${GREEN}"
log "完整域名：$FULL_DOMAIN" "${GREEN}"

log "脚本执行完毕，祝您使用愉快！" "${PURPLE}"
