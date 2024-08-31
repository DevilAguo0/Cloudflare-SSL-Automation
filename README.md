# Cloudflare SSL 自动化脚本 / Cloudflare SSL Automation Script

## 简介 / Introduction

[中文]
这是一个自动化脚本，用于在 Cloudflare 上为指定的域名申请和配置 SSL 证书。脚本会自动创建或更新 DNS A 记录，并使用 acme.sh 生成 SSL 证书。它提供了一个简单的交互式界面，使得整个过程变得简单和直观。

[English]
This is an automation script for requesting and configuring SSL certificates on Cloudflare for specified domains. The script automatically creates or updates DNS A records and generates SSL certificates using acme.sh. It provides a simple interactive interface that makes the entire process easy and intuitive.

## 功能 / Features

[中文]
- 自动安装必要的依赖（socat, jq）
- 自动安装和配置 acme.sh
- 创建或更新 Cloudflare DNS A 记录
- 为指定的域名生成 SSL 证书
- 将证书安装到指定路径
- 彩色输出，提高可读性
- 支持自定义二级域名

[English]
- Automatic installation of necessary dependencies (socat, jq)
- Automatic installation and configuration of acme.sh
- Creation or update of Cloudflare DNS A records
- SSL certificate generation for specified domains
- Installation of certificates to specified paths
- Colored output for improved readability
- Support for custom subdomains

## 使用方法 / Usage

[中文]
1. 克隆此仓库到您的服务器：
   ```
   git clone https://github.com/your-username/cloudflare-ssl-automation.git
   ```
2. 进入项目目录：
   ```
   cd cloudflare-ssl-automation
   ```
3. 给脚本添加执行权限：
   ```
   chmod +x cf_ssl_auto.sh
   ```
4. 以 root 权限运行脚本：
   ```
   sudo ./cf_ssl_auto.sh
   ```
5. 按照提示输入必要的信息（Cloudflare 邮箱、API 密钥、域名等）。
6. 脚本将自动完成剩余的步骤，包括创建 DNS 记录和生成 SSL 证书。

[English]
1. Clone this repository to your server:
   ```
   git clone https://github.com/your-username/cloudflare-ssl-automation.git
   ```
2. Navigate to the project directory:
   ```
   cd cloudflare-ssl-automation
   ```
3. Make the script executable:
   ```
   chmod +x cf_ssl_auto.sh
   ```
4. Run the script with root privileges:
   ```
   sudo ./cf_ssl_auto.sh
   ```
5. Follow the prompts to enter the necessary information (Cloudflare email, API key, domain, etc.).
6. The script will automatically complete the remaining steps, including creating DNS records and generating SSL certificates.

## 注意事项 / Notes

[中文]
- 请确保您有足够的权限来修改 Cloudflare 的 DNS 记录。
- 此脚本需要 root 权限来运行，因为它需要安装软件包和修改系统文件。
- 请妥善保管您的 Cloudflare API 密钥，不要将其泄露给他人。

[English]
- Ensure that you have sufficient permissions to modify Cloudflare DNS records.
- This script requires root privileges to run as it needs to install packages and modify system files.
- Keep your Cloudflare API key secure and do not share it with others.

## 贡献 / Contributing

[中文]
欢迎提交 issues 和 pull requests 来帮助改进这个项目。

[English]
Issues and pull requests are welcome to help improve this project.

## 许可证 / License

[中文]
本项目采用 MIT 许可证。详情请见 [LICENSE](LICENSE) 文件。

[English]
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
