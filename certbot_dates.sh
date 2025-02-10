#!/bin/bash

# 定义证书根目录
CERT_ROOT="/etc/letsencrypt/live"

# 检查证书根目录是否存在
if [ ! -d "$CERT_ROOT" ]; then
  echo "证书根目录不存在：$CERT_ROOT"
  exit 1
fi

# 列出证书根目录下的所有文件夹名称，忽略README文件夹
echo "证书根目录下的文件夹名称（忽略README文件夹）："
for dir in "$CERT_ROOT"/*; do
  if [ -d "$dir" ] && [ "$(basename "$dir")" != "README" ]; then
    echo "$(basename "$dir")"
  fi
done

# 提示用户输入证书文件夹名称
read -p "请输入证书文件夹名称（例如：example.com）: " CERT_FOLDER

# 检查用户是否输入了内容
if [ -z "$CERT_FOLDER" ]; then
  echo "未输入证书文件夹名称，脚本将退出。"
  exit 1
fi

# 构造证书路径
CERT_PATH="$CERT_ROOT/$CERT_FOLDER/fullchain.pem"

# 检查证书文件是否存在
if [ ! -f "$CERT_PATH" ]; then
  echo "证书文件不存在：$CERT_PATH"
  exit 1
fi

# 获取证书的过期时间
EXPIRE_DATE=$(openssl x509 -in "$CERT_PATH" -noout -enddate | cut -d= -f2)

# 检查是否成功获取过期时间
if [ -z "$EXPIRE_DATE" ]; then
  echo "无法获取证书的过期时间，请检查证书路径或证书内容。"
  exit 1
fi

# 将时间格式转换为中文
# 使用date命令将GMT时间转换为本地时间，并格式化为中文日期格式
CHINESE_EXPIRE_DATE=$(date -d "$EXPIRE_DATE" +"%Y年%m月%d日 %H时%M分%S秒")

# 输出结果
echo "证书过期时间：$CHINESE_EXPIRE_DATE"