   #!/bin/bash

   VERSION="1.0.1"
   SCRIPT_NAME="yord-ssl-setup"
   INSTALL_DIR="/usr/local/bin"
   SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"
   SOURCE_URL="https://raw.githubusercontent.com/YordYI/Cloudflare-SSL-Automation/main/cloudflare_ssl.sh"
   LOG_FILE="/var/log/$SCRIPT_NAME-install.log"

   echo "Yord SSL Setup 安装脚本 v$VERSION 开始执行"

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

   echo "开始下载脚本..."
   if curl -o "$SCRIPT_PATH" "$SOURCE_URL"; then
       chmod +x "$SCRIPT_PATH"
       echo "$SCRIPT_NAME 已成功安装到 $SCRIPT_PATH"
       echo "您可以通过运行 '$SCRIPT_NAME' 来使用该脚本。"
   else
       echo "下载脚本失败，请检查网络连接或脚本URL。"
       exit 1
   fi
