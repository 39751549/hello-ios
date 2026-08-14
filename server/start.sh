#!/usr/bin/env bash
# 一键启动脚本 (Linux / 宝塔面板)
# 用法: bash start.sh
set -e
cd "$(dirname "$0")"

PY=${PYTHON:-python3}

# 1. 安装依赖(首次)
if ! $PY -c "import fastapi" 2>/dev/null; then
  echo ">>> 安装依赖..."
  $PY -m pip install -r requirements.txt
fi

# 2. 初始化数据库表+基础数据
echo ">>> 初始化数据库..."
$PY init_data.py

# 3. 启动服务
PORT=${PORT:-9888}
HOST=${HOST:-0.0.0.0}
echo ">>> 启动服务: http://${HOST}:${PORT}"
echo ">>> GM 后台: http://127.0.0.1:${PORT}/admin/  (admin/admin)"
exec $PY -m uvicorn main:app --host ${HOST} --port ${PORT}
