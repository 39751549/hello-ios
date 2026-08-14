# -*- coding: utf-8 -*-
"""全局配置"""
import os

# ============ MySQL 配置 ============
DB_HOST = os.getenv("DB_HOST", "180.184.41.230")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "youxi")
DB_PASSWORD = os.getenv("DB_PASSWORD", "7ttLpWwGS5pHh65L")
DB_NAME = os.getenv("DB_NAME", "youxi")

DATABASE_URL = (
    f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    f"?charset=utf8mb4"
)

# ============ JWT ============
SECRET_KEY = os.getenv("SECRET_KEY", "youxi-game-secret-2026-please-change")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7 天

# ============ GM 默认账号 ============
GM_DEFAULT_USER = "admin"
GM_DEFAULT_PASSWORD = "admin"

# ============ 游戏配置 ============
MAX_LEVEL = 120
# 升级所需经验公式: next_exp = BASE * level^FACTOR
EXP_BASE = 80
EXP_FACTOR = 1.6

# 初始玩家属性
INIT_LEVEL = 1
INIT_GOLD = 1000          # 游戏币
INIT_DIAMOND = 0          # 充值币
INIT_HP = 200
INIT_ATK = 20
INIT_DEF = 10

# 充值比例: 1 元 = 10 钻石
RECHARGE_RATE = 10
