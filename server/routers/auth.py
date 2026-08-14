# -*- coding: utf-8 -*-
"""账号系统:注册/登录"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
import models
import schemas
from security import hash_password, verify_password, create_access_token
from config import INIT_LEVEL, INIT_GOLD, INIT_DIAMOND, INIT_HP, INIT_ATK, INIT_DEF

router = APIRouter(prefix="/api/auth", tags=["auth"])

# 新手赠送物品 code
STARTER_ITEMS = [("w_iron", 1), ("a_cloth", 1), ("c_hp_s", 3), ("s_novice", 1)]


@router.post("/register", response_model=schemas.ApiResult)
def register(req: schemas.RegisterIn, db: Session = Depends(get_db)):
    username = req.username.strip()
    if len(username) < 3:
        raise HTTPException(400, "用户名至少3位")
    if len(req.password) < 6:
        raise HTTPException(400, "密码至少6位")
    if db.query(models.User).filter_by(username=username).first():
        raise HTTPException(400, "用户名已存在")
    user = models.User(username=username, password_hash=hash_password(req.password))
    db.add(user)
    db.commit()
    db.refresh(user)

    nickname = req.nickname.strip() or username
    player = models.Player(
        user_id=user.id, nickname=nickname,
        level=INIT_LEVEL, gold=INIT_GOLD, diamond=INIT_DIAMOND,
        hp=INIT_HP, atk=INIT_ATK, df=INIT_DEF, cur_hp=INIT_HP,
    )
    db.add(player)
    db.commit()
    db.refresh(player)

    # 赠送新手装备
    for code, cnt in STARTER_ITEMS:
        item = db.query(models.Item).filter_by(code=code).first()
        if item:
            db.add(models.PlayerItem(player_id=player.id, item_id=item.id, count=cnt))
    # 自动装备新手装
    novice = db.query(models.Item).filter_by(code="s_novice").first()
    iron = db.query(models.Item).filter_by(code="w_iron").first()
    cloth = db.query(models.Item).filter_by(code="a_cloth").first()
    if novice:
        player.equip_skin = novice.id
    if iron:
        player.equip_weapon = iron.id
    if cloth:
        player.equip_armor = cloth.id
    db.commit()

    token = create_access_token({"uid": user.id})
    return schemas.ApiResult(data={"token": token, "player_id": player.id})


@router.post("/login", response_model=schemas.ApiResult)
def login(req: schemas.LoginIn, db: Session = Depends(get_db)):
    user = db.query(models.User).filter_by(username=req.username.strip()).first()
    if not user or not verify_password(req.password, user.password_hash):
        raise HTTPException(400, "用户名或密码错误")
    from datetime import datetime
    user.last_login = datetime.utcnow()
    db.commit()
    token = create_access_token({"uid": user.id})
    return schemas.ApiResult(data={"token": token})
