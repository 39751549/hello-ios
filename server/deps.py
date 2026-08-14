# -*- coding: utf-8 -*-
"""FastAPI 依赖:从 token 解析当前用户/玩家"""
from fastapi import Depends, HTTPException, Header
from jose import JWTError
from security import decode_token
from database import get_db
import models


def get_current_user(authorization: str = Header(default=""), db=Depends(get_db)):
    if not authorization:
        raise HTTPException(401, "缺少认证信息")
    token = authorization.replace("Bearer ", "").strip()
    try:
        payload = decode_token(token)
        uid = payload.get("uid")
    except JWTError:
        raise HTTPException(401, "token 无效或已过期")
    user = db.query(models.User).filter_by(id=uid).first()
    if not user:
        raise HTTPException(401, "用户不存在")
    return user


def get_current_player(authorization: str = Header(default=""), db=Depends(get_db)):
    user = get_current_user(authorization, db)
    player = db.query(models.Player).filter_by(user_id=user.id).first()
    if not player:
        raise HTTPException(404, "角色不存在")
    return player
