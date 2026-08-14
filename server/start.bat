@echo off
REM 一键启动脚本 (Windows 本地调试)
cd /d "%~dp0"

set PY=python
if not defined PYTHON set PYTHON=python

%PY% -c "import fastapi" 2>nul
if errorlevel 1 (
  echo >>> 安装依赖...
  %PY% -m pip install -r requirements.txt
)

echo >>> 初始化数据库...
%PY% init_data.py

if "%PORT%"=="" set PORT=9888
if "%HOST%"=="" set HOST=0.0.0.0
echo >>> 启动服务: http://%HOST%:%PORT%
echo >>> GM 后台: http://127.0.0.1:%PORT%/admin/  (admin/admin)
%PY% -m uvicorn main:app --host %HOST% --port %PORT%
