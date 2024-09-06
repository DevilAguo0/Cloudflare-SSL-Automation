   #!/bin/bash

   # 定义脚本的 URL
   SCRIPT_URL="https://raw.githubusercontent.com/YordYI/Cloudflare-SSL-Automation/main/cloudflare_ssl.sh"

   # 下载脚本
   curl -sSL $SCRIPT_URL -o /tmp/cloudflare_ssl.sh

   # 给脚本执行权限
   chmod +x /tmp/cloudflare_ssl.sh

   # 执行脚本
   /tmp/cloudflare_ssl.sh
