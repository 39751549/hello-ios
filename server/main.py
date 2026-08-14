# -*- coding: utf-8 -*-
"""游戏服务端入口 (FastAPI)
启动: uvicorn main:app --host 0.0.0.0 --port 9888
"""
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse

import init_data
from routers import auth, player, battle, gacha, shop, boss
from admin import gm


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 启动时建表 + 初始化基础数据
    init_data.init_all()
    yield


app = FastAPI(title="Youxi Game Server", version="1.0.0", lifespan=lifespan)

# CORS(允许 iOS 客户端跨域)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 路由
app.include_router(auth.router)
app.include_router(player.router)
app.include_router(battle.router)
app.include_router(gacha.router)
app.include_router(shop.router)
app.include_router(boss.router)
app.include_router(gm.router)


@app.get("/")
def root():
    return RedirectResponse("/admin/")


@app.get("/api/health")
def health():
    return {"code": 0, "msg": "ok", "data": {"service": "youxi", "version": "1.0.0"}}


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "9888"))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
