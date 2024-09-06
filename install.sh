#!/bin/bash

VERSION="1.0.0"
LOG_FILE="/var/log/yord-ssl-setup-install.log"

echo "Yord SSL Setup 安装脚本 v$VERSION"

# 权限检查
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要root权限运行。"
    exit 1
fi

# 依赖检查
for cmd in curl chmod; do
    if ! command -v $cmd &> /dev/null; then
        echo "$cmd 未安装，请先安装。"
        exit 1
    fi
done

# 卸载选项
if [ "$1" = "uninstall" ]; then
    rm -f /usr/local/bin/yord-ssl-setup
    echo "Yord SSL Setup 已卸载。"
    exit 0
fi

# 安装确认
read -p "是否安装 Yord SSL Setup? (y/n) " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "安装已取消。"
    exit 1
fi

echo "$(date): 开始安装 Yord SSL Setup" >> $LOG_FILE

# 下载脚本
if ! curl -o /usr/local/bin/yord-ssl-setup https://raw.githubusercontent.com/YordYI/Cloudflare-SSL-Automation/main/cloudflare_ssl.sh; then
    echo "下载脚本失败，请检查网络连接或脚本URL。"
    echo "$(date): 下载脚本失败" >> $LOG_FILE
    exit 1
fi

# 添加执行权限
chmod +x /usr/local/bin/yord-ssl-setup

echo "Yord SSL Setup 已安装成功！运行 'yord-ssl-setup' 来使用。"
echo "$(date): Yord SSL Setup 安装完成" >> $LOG_FILE
