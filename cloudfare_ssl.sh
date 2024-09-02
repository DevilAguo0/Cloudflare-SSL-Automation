#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置文件
CONFIG_FILE="/root/.yord_config"

# 打印横幅
print_banner() {
    echo -e "${PURPLE}"
    echo '
 __   __              _   __   __ _____ 
 \ \ / /__  _ __ __ _| |  \ \ / /|_   _|
  \ V / _ \| `__/ _` | |   \ V /   | |  
   | | (_) | | | (_| | |    | |    | |  
   |_|\___/|_|  \__,_|_|    |_|    |_|  
    '
    echo -e "${NC}"
    echo -e "${CYAN}欢迎使用 Yord SSL 自动配置脚本${NC}"
    echo -e "${YELLOW}本脚本将帮助您自动配置 Cloudflare DNS 并获取 SSL 证书${NC}"
    echo -e "${YELLOW}作者: Yord YI${NC}"
    echo
}

# 日志函数
log() {
    echo -e "${CYAN}[Yord SSL] $(date '+%Y-%m-%d %H:%M:%S')${NC} ${2}${1}${NC}"
}

# 检查并安装依赖
install_dependencies() {
    for pkg in curl socat jq cron; do
        if ! command -v $pkg &> /dev/null; then
            log "正在安装 $pkg..." "${BLUE}"
            apt-get update && apt-get install -y $pkg || { log "安装 $pkg 失败" "${RED}"; exit 1; }
        fi
    done
}

# 加载或创建配置
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        read -p "$(echo -e ${YELLOW}"请输入 Cloudflare 邮箱: "${NC})" CF_Email
        read -s -p "$(echo -e ${YELLOW}"请输入 Cloudflare API 密钥: "${NC})" CF_Key
        echo
        echo "CF_Email='$CF_Email'" > "$CONFIG_FILE"
        echo "CF_Key='$CF_Key'" >> "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
    fi
}

# Cloudflare API 调用函数
cf_api_call() {
    curl -s -X "$1" "https://api.cloudflare.com/client/v4$2" \
         -H "X-Auth-Email: $CF_Email" \
         -H "X-Auth-Key: $CF_Key" \
         -H "Content-Type: application/json" \
         ${3:+--data "$3"}
}

# 主函数
main() {
    print_banner
    install_dependencies
    load_config

    read -p "$(echo -e ${YELLOW}"请输入主域名: "${NC})" DOMAIN
    read -p "$(echo -e ${YELLOW}"请输入二级域名 (不包括主域名部分): "${NC})" SUBDOMAIN

    FULL_DOMAIN="${SUBDOMAIN}.${DOMAIN}"

    # 获取 Zone ID
    log "正在获取 Zone ID..." "${BLUE}"
    ZONE_ID=$(cf_api_call GET "/zones?name=$DOMAIN" | jq -r '.result[0].id')
    [ -z "$ZONE_ID" ] && { log "无法获取 Zone ID，请检查域名和 API 凭证。" "${RED}"; exit 1; }

    # 检查并创建 DNS 记录
    log "正在检查 DNS 记录..." "${BLUE}"
    RECORD_ID=$(cf_api_call GET "/zones/$ZONE_ID/dns_records?type=A&name=$FULL_DOMAIN" | jq -r '.result[0].id')
    if [ -z "$RECORD_ID" ] || [ "$RECORD_ID" = "null" ]; then
        SERVER_IP=$(curl -s ifconfig.me)
        log "正在创建 A 记录..." "${BLUE}"
        RECORD_RESPONSE=$(cf_api_call POST "/zones/$ZONE_ID/dns_records" \
            "{\"type\":\"A\",\"name\":\"$FULL_DOMAIN\",\"content\":\"$SERVER_IP\",\"ttl\":1,\"proxied\":false}")
        echo "$RECORD_RESPONSE" | jq -e '.success' &>/dev/null || { log "A 记录创建失败" "${RED}"; exit 1; }
        log "A 记录创建成功" "${GREEN}"
    else
        log "DNS 记录已存在" "${YELLOW}"
    fi

    # 安装和配置 acme.sh
    log "正在配置 acme.sh..." "${BLUE}"
    curl https://get.acme.sh | sh -s email=$CF_Email
    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    ~/.acme.sh/acme.sh --issue --dns dns_cf -d "$FULL_DOMAIN" --force
    ~/.acme.sh/acme.sh --installcert -d "$FULL_DOMAIN" \
        --key-file /root/private.key \
        --fullchain-file /root/cert.crt

    # 设置自动更新
    log "正在设置自动更新..." "${BLUE}"
    (crontab -l 2>/dev/null; echo "0 0 1 * * ~/.acme.sh/acme.sh --cron --home ~/.acme.sh > /dev/null") | crontab -

    log "SSL 证书配置完成！" "${GREEN}"
    log "证书文件: /root/cert.crt" "${GREEN}"
    log "密钥文件: /root/private.key" "${GREEN}"
}

main
