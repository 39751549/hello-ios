# -*- coding: utf-8 -*-
"""游戏配置接口(云更新核心)
客户端启动时 GET /api/config 拉取全量配置,覆盖本地默认值。
GM 后台可编辑这些配置,无需重新打包客户端。
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
import models
from schemas import ApiResult

router = APIRouter(prefix="/api", tags=["config"])


@router.get("/config")
def get_game_config(db: Session = Depends(get_db)):
    """返回全量配置 (key -> value)。
    无需登录,客户端启动即可拉取。"""
    rows = db.query(models.GameConfig).all()
    cfg = {r.key: r.value for r in rows}
    return ApiResult(data=cfg)
