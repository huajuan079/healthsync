#!/bin/bash
set -e

# ============================================================
# Health Sync Server 部署脚本
# 目标服务器: 129.226.145.68
# 部署路径: /opt/health-sync/
# 访问地址: https://markmager.cc/healthsync/
# ============================================================

PEM="/Users/dongsen/Documents/Code/private/tencentCloud/MarkMager/MarkMager.pem"
SERVER="root@129.226.145.68"
REMOTE_DIR="/opt/health-sync"
MARKMAGER_DIR="/opt/markmager-web"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/health-sync-server"

SSH="ssh -i $PEM -o StrictHostKeyChecking=no"
SCP="scp -i $PEM -o StrictHostKeyChecking=no"

echo "========================================"
echo " Health Sync Server 部署开始"
echo "========================================"

# ── Step 1: 创建服务器目录 ────────────────────────────────
echo ""
echo "[1/6] 创建服务器目录..."
$SSH $SERVER "mkdir -p $REMOTE_DIR"

# ── Step 2: 上传源码 ───────────────────────────────────────
echo ""
echo "[2/6] 上传源码到服务器..."
rsync -avz --progress \
  -e "ssh -i $PEM -o StrictHostKeyChecking=no" \
  --exclude node_modules \
  --exclude dist \
  --exclude .env \
  --exclude "*.db" \
  --exclude storage \
  --exclude ".git" \
  "$SOURCE_DIR/" "$SERVER:$REMOTE_DIR/"

# ── Step 3: 生成 .env（首次部署自动生成密钥）─────────────
echo ""
echo "[3/6] 配置环境变量..."
$SSH $SERVER "bash -s" << 'REMOTE_SCRIPT'
if [ ! -f /opt/health-sync/.env ]; then
  echo "首次部署，自动生成 JWT 密钥..."
  JWT_SECRET=$(openssl rand -hex 64)
  JWT_REFRESH_SECRET=$(openssl rand -hex 64)

  cat > /opt/health-sync/.env << EOF
NODE_ENV=production
PORT=3000
DATABASE_URL=file:/app/data/health-sync.db
JWT_SECRET=$JWT_SECRET
JWT_REFRESH_SECRET=$JWT_REFRESH_SECRET
JWT_EXPIRES_IN=1h
JWT_REFRESH_EXPIRES_IN=30d
CORS_ORIGIN=https://markmager.cc
DATA_RETENTION_DAYS=7
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
EOF
  echo ".env 创建成功"
else
  echo ".env 已存在，跳过生成（保留现有密钥）"
fi
REMOTE_SCRIPT

# ── Step 4: 构建并启动 health-sync 容器 ───────────────────
echo ""
echo "[4/6] 构建并启动 health-sync-server 容器..."
$SSH $SERVER "cd $REMOTE_DIR && docker-compose down 2>/dev/null || true && docker-compose up -d --build"

# 等待容器就绪
echo "等待容器启动..."
sleep 5
$SSH $SERVER "docker ps | grep health-sync-server"

# ── Step 5: 更新 markmager-web nginx 配置 ─────────────────
echo ""
echo "[5/6] 更新 Nginx 配置（添加 /healthsync/ 代理）..."

$SSH $SERVER "cat > /tmp/nginx-https-new.conf" << 'NGINX_EOF'
# HTTP -> HTTPS 重定向
server {
    listen 80;
    server_name markmager.cc www.markmager.cc;
    return 301 https://$server_name$request_uri;
}

# HTTPS 服务器
server {
    listen 443 ssl http2;
    server_name markmager.cc www.markmager.cc;

    # SSL 证书
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;

    # SSL 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    root /usr/share/nginx/html;
    index index.html;

    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json application/javascript;

    # HealthSync API 代理 - /healthsync/ -> health-sync-server:3000/
    location /healthsync/ {
        proxy_pass http://health-sync-server:3000/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
        proxy_send_timeout 300s;
    }

    # SPA 路由
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 静态资源缓存
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
NGINX_EOF

$SSH $SERVER "cp /tmp/nginx-https-new.conf $MARKMAGER_DIR/nginx-https.conf"

# ── Step 6: 热重载 nginx（零停机）────────────────────────
echo ""
echo "[6/6] 热重载 Nginx 配置（零停机）..."
$SSH $SERVER "docker cp /tmp/nginx-https-new.conf markmager-web:/etc/nginx/conf.d/default.conf"
$SSH $SERVER "docker exec markmager-web nginx -t" && echo "Nginx 配置语法正确"
$SSH $SERVER "docker exec markmager-web nginx -s reload"
echo "Nginx 已热重载"

# ── 验证部署 ──────────────────────────────────────────────
echo ""
echo "========================================"
echo " 验证部署状态"
echo "========================================"
$SSH $SERVER "docker ps | grep -E 'health-sync|markmager'"

echo ""
echo "测试 health-sync 接口..."
$SSH $SERVER "curl -s -o /dev/null -w 'HTTP Status: %{http_code}' http://localhost/healthsync/api/auth/me -H 'Content-Type: application/json' 2>/dev/null || echo '连接失败'"

echo ""
echo "========================================"
echo " 部署完成！"
echo "========================================"
echo ""
echo "服务地址: https://markmager.cc/healthsync"
echo "API 示例:"
echo "  POST https://markmager.cc/healthsync/api/auth/login"
echo "  POST https://markmager.cc/healthsync/api/health/upload"
echo "  GET  https://markmager.cc/healthsync/api/health/status"
echo ""
echo "⚠️  记得更新以下配置："
echo "  iOS App:    AppContainer.swift → Config.serverURL = \"https://markmager.cc/healthsync\""
echo "  Mac Mini:   .env → SERVER_URL=https://markmager.cc/healthsync"
echo ""
echo "查看日志: ssh -i $PEM $SERVER 'docker logs -f health-sync-server'"
