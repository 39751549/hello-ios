# -*- coding: utf-8 -*-
"""游戏服务端入口 (FastAPI)
启动: uvicorn main:app --host 0.0.0.0 --port 9888
"""
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse

import init_data
from routers import auth, player, battle, gacha, shop, boss, config
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
app.include_router(config.router)
app.include_router(gm.router)


@app.get("/")
def root():
    return RedirectResponse("/admin/")


@app.get("/api/health")
def health():
    return {"code": 0, "msg": "ok", "data": {"service": "youxi", "version": "1.0.0"}}


@app.post("/api/crash_log")
def crash_log(payload: dict = Body(default={})):
    """接收客户端崩溃日志, 落盘到 crashes/ 方便排查。"""
    import datetime
    os.makedirs("crashes", exist_ok=True)
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    crash = payload.get("crash", "")
    device = payload.get("device", "?")
    system = payload.get("system", "?")
    appv = payload.get("app", "?")
    fname = f"crashes/crash_{ts}_{os.getpid()}.txt"
    with open(fname, "w", encoding="utf-8") as f:
        f.write(f"device={device} system={system} app={appv}\n\n{crash}\n")
    print(f"[CRASH] 收到崩溃日志 -> {fname}\n{crash[:400]}\n---")
    return {"code": 0, "msg": "ok"}


# ---- IPA 下载(版本更新用)----
@app.get("/download/app")
def download_app():
    """下载最新 IPA。把 HelloApp.ipa 放到服务端 downloads/ 目录即可。"""
    from fastapi.responses import FileResponse
    from fastapi import HTTPException
    path = "downloads/HelloApp.ipa"
    if not os.path.exists(path):
        raise HTTPException(404, "IPA 未上传,请把 HelloApp.ipa 放到 downloads/ 目录")
    return FileResponse(path, filename="HelloApp.ipa",
                        media_type="application/octet-stream")


@app.get("/api/version")
def version_check():
    """客户端版本检查:返回最新版本号和下载地址(GM 在后台配置)。"""
    from database import SessionLocal
    import models
    db = SessionLocal()
    try:
        cfg = {c.key: c.value for c in db.query(models.GameConfig).all()}
        return {
            "code": 0,
            "data": {
                "force_update_version": int(cfg.get("force_update_version", "0") or "0"),
                "update_url": cfg.get("update_url", ""),
                "latest_version": cfg.get("latest_version", "1"),
            }
        }
    finally:
        db.close()


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", "9888"))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
