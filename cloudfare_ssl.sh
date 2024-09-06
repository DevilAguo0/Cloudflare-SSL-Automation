#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置文件路径
CONFIG_FILE="/etc/cloudflaressl.conf"

# 日志函数
log() {
    echo -e "${CYAN}[Yord YI] $(date '+%Y-%m-%d %H:%M:%S')${NC} ${2}${1}${NC}"
}

# 错误处理函数
error_exit() {
    log "$1" "${RED}"
    exit 1
}

# 检查命令是否可用
check_command() {
    command -v "$1" >/dev/null 2>&1 || error_exit "错误：需要 $1 命令，但它没有安装。请安装后再运行此脚本。"
}

# 加密函数
encrypt() {
    echo "$1" | openssl enc -aes-256-cbc -a -salt -pass pass:YordYISecretKey
}

# 解密函数
decrypt() {
    echo "$1" | openssl enc -aes-256-cbc -d -a -salt -pass pass:YordYISecretKey
}

# 保存配置
save_config() {
    local encrypted_email=$(encrypt "$CF_Email")
    local encrypted_key=$(encrypt "$CF_Key")
    local encrypted_domain=$(encrypt "$DOMAIN")

    cat > "$CONFIG_FILE" << EOF
CF_Email="$encrypted_email"
CF_Key="$encrypted_key"
DOMAIN="$encrypted_domain"
EOF
    chmod 600 "$CONFIG_FILE"
    log "配置已加密保存" "${GREEN}"
}

# 加载配置
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        CF_Email=$(decrypt "$CF_Email")
        CF_Key=$(decrypt "$CF_Key")
        DOMAIN=$(decrypt "$DOMAIN")
        return 0
    fi
    return 1
}

# 检查必要的命令
check_command curl
check_command jq
check_command openssl

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    error_exit "错误：请以 root 权限运行此脚本"
fi

# 尝试加载配置
if ! load_config; then
    # 获取用户输入
    read -p "$(echo -e ${YELLOW}"请输入 Cloudflare 邮箱: "${NC})" CF_Email
    [ -z "$CF_Email" ] && error_exit "错误：Cloudflare 邮箱不能为空"

    read -p "$(echo -e ${YELLOW}"请输入 Cloudflare API 密钥: "${NC})" CF_Key
    [ -z "$CF_Key" ] && error_exit "错误：Cloudflare API 密钥不能为空"

    read -p "$(echo -e ${YELLOW}"请输入主域名: "${NC})" DOMAIN
    [ -z "$DOMAIN" ] && error_exit "错误：主域名不能为空"

    # 保存配置
    save_config
else
    log "已加载保存的配置" "${GREEN}"
fi

get_subdomain() {
    while true; do
        read -p "$(echo -e ${YELLOW}"请输入二级域名 (不包括主域名部分): "${NC})" SUBDOMAIN
        [ -z "$SUBDOMAIN" ] && error_exit "错误：二级域名不能为空"
        FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"
        
        # 检查记录是否已存在
        EXISTING_RECORD=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$FULL_DOMAIN" \
             -H "X-Auth-Email: $CF_Email" \
             -H "X-Auth-Key: $CF_Key" \
             -H "Content-Type: application/json")

        RECORD_ID=$(echo $EXISTING_RECORD | jq -r '.result[0].id')
        
        if [ "$RECORD_ID" != "null" ] && [ -n "$RECORD_ID" ]; then
            log "A 记录 $FULL_DOMAIN 已存在。请输入一个不同的二级域名。" "${YELLOW}"
        else
            break
        fi
    done
}

# 检查并安装 acme.sh
install_acme() {
    log "正在安装 acme.sh..." "${BLUE}"
    curl https://get.acme.sh | sh -s email="$CF_Email" || error_exit "错误：安装 acme.sh 失败"
    source ~/.bashrc
}

# 检查 acme.sh 是否已安装
ACME_SH="/root/.acme.sh/acme.sh"
if [ ! -f "$ACME_SH" ]; then
    install_acme
else
    log "acme.sh 已安装在 $ACME_SH" "${GREEN}"
fi

# 确保 acme.sh 是可执行的
chmod +x "$ACME_SH"

# 获取 Zone ID
log "正在获取 Zone ID..." "${BLUE}"
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" \
     -H "X-Auth-Email: $CF_Email" \
     -H "X-Auth-Key: $CF_Key" \
     -H "Content-Type: application/json" | jq -r '.result[0].id')

[ -z "$ZONE_ID" ] || [ "$ZONE_ID" == "null" ] && error_exit "错误：无法获取 Zone ID，请检查域名和 API 凭证。"

# 获取服务器 IP
SERVER_IP=$(curl -s ifconfig.me)
[ -z "$SERVER_IP" ] && error_exit "错误：无法获取服务器 IP"
log "服务器 IP: $SERVER_IP" "${GREEN}"

# 获取二级域名并创建 A 记录
get_subdomain

# 创建 A 记录
log "正在创建 A 记录..." "${BLUE}"
RECORD_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
     -H "X-Auth-Email: $CF_Email" \
     -H "X-Auth-Key: $CF_Key" \
     -H "Content-Type: application/json" \
     --data "{\"type\":\"A\",\"name\":\"$FULL_DOMAIN\",\"content\":\"$SERVER_IP\",\"ttl\":1,\"proxied\":false}")

if echo "$RECORD_RESPONSE" | jq -e '.success' &>/dev/null; then
    log "A 记录创建成功" "${GREEN}"
else
    error_exit "错误：A 记录创建失败。错误信息：\n$(echo "$RECORD_RESPONSE" | jq '.errors')"
fi

# 生成证书
log "正在生成证书..." "${BLUE}"
"$ACME_SH" --issue --dns dns_cf -d $FULL_DOMAIN || error_exit "错误：生成证书失败"

# 创建证书目录
mkdir -p /etc/nginx/ssl

# 安装证书到指定路径
log "正在安装证书..." "${BLUE}"
"$ACME_SH" --install-cert -d $FULL_DOMAIN \
    --key-file /etc/nginx/ssl/$FULL_DOMAIN.key  \
    --fullchain-file /etc/nginx/ssl/$FULL_DOMAIN.crt || error_exit "错误：安装证书失败"

# 配置自动更新
log "配置证书自动更新..." "${BLUE}"
"$ACME_SH" --upgrade --auto-upgrade || log "警告：配置自动更新失败，请手动检查" "${YELLOW}"

# 输出证书路径和完整的域名
log "证书生成和安装成功！" "${GREEN}"
log "证书路径：" "${GREEN}"
log "密钥文件：/etc/nginx/ssl/$FULL_DOMAIN.key" "${GREEN}"
log "证书文件：/etc/nginx/ssl/$FULL_DOMAIN.crt" "${GREEN}"
log "完整域名：$FULL_DOMAIN" "${GREEN}"

log "恭喜！脚本执行成功，祝您使用愉快！" "${GREEN}"
