#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

# 日志函数
log() {
    echo -e "${CYAN}[Yord YI] $(date '+%Y-%m-%d %H:%M:%S')${NC} ${2}${1}${NC}"
}

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    log "请以 root 权限运行此脚本" "${RED}"
    exit 1
fi

# 提示输入 Cloudflare 邮箱、API 密钥、主域名和二级域名
read -p "$(echo -e ${YELLOW}"请输入 Cloudflare 邮箱: "${NC})" CF_Email
read -p "$(echo -e ${YELLOW}"请输入 Cloudflare API 密钥: "${NC})" CF_Key
read -p "$(echo -e ${YELLOW}"请输入主域名: "${NC})" DOMAIN
read -p "$(echo -e ${YELLOW}"请输入二级域名 (不包括主域名部分): "${NC})" SUBDOMAIN

FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"

# 安装必要的软件
for pkg in socat jq; do
    if ! command -v $pkg &> /dev/null; then
        log "正在安装 $pkg..." "${BLUE}"
        apt-get update && apt-get install -y $pkg || { log "安装 $pkg 失败" "${RED}"; exit 1; }
    fi
done

# 检查并安装 acme.sh
install_acme() {
    log "正在安装 acme.sh..." "${BLUE}"
    curl https://get.acme.sh | sh -s email=$CF_Email
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
        cp "$HIDDIFY_ACME" "$ACME_SH"
        if [ -f "$ACME_SH" ]; then
            log "已复制 acme.sh 到 $ACME_SH" "${GREEN}"
        else
            log "复制 acme.sh 失败" "${RED}"
            install_acme
        fi
    fi
else
    install_acme
fi

# 再次检查 acme.sh 是否可用
if [ ! -f "$ACME_SH" ]; then
    log "acme.sh 安装失败或无法找到。请手动安装并确保它在 $ACME_SH 路径下。" "${RED}"
    exit 1
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

if [ -z "$ZONE_ID" ]; then
    log "无法获取 Zone ID，请检查域名和 API 凭证。" "${RED}"
    exit 1
fi

# 获取服务器 IP
SERVER_IP=$(curl -s ifconfig.me)
log "服务器 IP: $SERVER_IP" "${GREEN}"

# 创建或更新 A 记录
log "正在创建或更新 A 记录..." "${BLUE}"
RECORD_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
     -H "X-Auth-Email: $CF_Email" \
     -H "X-Auth-Key: $CF_Key" \
     -H "Content-Type: application/json" \
     --data "{\"type\":\"A\",\"name\":\"$FULL_DOMAIN\",\"content\":\"$SERVER_IP\",\"ttl\":1,\"proxied\":false}")

if echo "$RECORD_RESPONSE" | jq -e '.success' &>/dev/null; then
    log "A 记录创建或更新成功" "${GREEN}"
else
    log "A 记录创建或更新失败。错误信息：" "${RED}"
    echo "$RECORD_RESPONSE" | jq '.errors'
    exit 1
fi

# 生成证书
log "正在生成证书..." "${BLUE}"
"$ACME_SH" --issue --dns dns_cf -d $FULL_DOMAIN || { log "生成证书失败" "${RED}"; exit 1; }

# 创建证书目录
mkdir -p /etc/nginx/ssl

# 安装证书到指定路径
log "正在安装证书..." "${BLUE}"
"$ACME_SH" --install-cert -d $FULL_DOMAIN \
    --key-file /etc/nginx/ssl/$FULL_DOMAIN.key  \
    --fullchain-file /etc/nginx/ssl/$FULL_DOMAIN.crt || { log "安装证书失败" "${RED}"; exit 1; }

# 输出证书路径和完整的域名
log "证书生成和安装成功！" "${GREEN}"
log "证书路径：" "${GREEN}"
log "密钥文件：/etc/nginx/ssl/$FULL_DOMAIN.key" "${GREEN}"
log "证书文件：/etc/nginx/ssl/$FULL_DOMAIN.crt" "${GREEN}"
log "完整域名：$FULL_DOMAIN" "${GREEN}"

log "脚本执行完毕，祝您使用愉快！" "${PURPLE}"
