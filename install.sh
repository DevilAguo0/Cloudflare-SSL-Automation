   #!/bin/bash

   VERSION="1.0.2"
   SCRIPT_NAME="yord-ssl-setup"
   INSTALL_DIR="/usr/local/bin"
   SCRIPT_PATH="$INSTALL_DIR/$SCRIPT_NAME"
   SOURCE_URL="https://raw.githubusercontent.com/YordYI/Cloudflare-SSL-Automation/main/cloudflare_ssl.sh"
   LOG_FILE="/var/log/$SCRIPT_NAME-install.log"

   log() {
       echo "$(date): $1" | tee -a "$LOG_FILE"
   }

   error() {
       echo "$(date): [错误] $1" | tee -a "$LOG_FILE"
       exit 1
   }

   # 权限检查
   [[ $EUID -ne 0 ]] && error "此脚本需要root权限运行。请使用sudo或以root身份运行。"

   # 依赖检查
   for cmd in curl chmod; do
       command -v $cmd >/dev/null 2>&1 || error "$cmd 未安装，请先安装。"
   done

   # 卸载函数
   uninstall() {
       if [[ -f "$SCRIPT_PATH" ]]; then
           rm -f "$SCRIPT_PATH" && log "$SCRIPT_NAME 已卸载。"
       else
           log "$SCRIPT_NAME 未安装，无需卸载。"
       fi
       exit 0
   }

   # 主函数
   main() {
       log "$SCRIPT_NAME 安装脚本 v$VERSION 开始执行"

       # 处理卸载选项
       [[ "$1" == "uninstall" ]] && uninstall

       # 安装确认
       while true; do
           read -p "是否安装 $SCRIPT_NAME? (y/n) " yn
           case $yn in
               [Yy]* ) break;;
               [Nn]* ) log "安装已取消。"; exit 0;;
               * ) echo "请回答 yes 或 no.";;
           esac
       done

       log "开始下载脚本..."
       if curl -sSL "$SOURCE_URL" -o "$SCRIPT_PATH"; then
           chmod +x "$SCRIPT_PATH"
           log "$SCRIPT_NAME 已成功安装到 $SCRIPT_PATH"
           log "您可以通过运行 '$SCRIPT_NAME' 来使用该脚本。"
       else
           error "下载脚本失败，请检查网络连接或脚本URL。"
       fi
   }

   # 执行主函数
   main "$@"
