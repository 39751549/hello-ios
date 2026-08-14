# -*- coding: utf-8 -*-
"""Boss 列表"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from database import get_db
import schemas

router = APIRouter(prefix="/api/boss", tags=["boss"])


@router.get("/list", response_model=schemas.ApiResult)
def boss_list(db: Session = Depends(get_db)):
    from models import Boss
    bosses = db.query(Boss).order_by(Boss.tier.asc(), Boss.level.asc()).all()
    data = []
    for b in bosses:
        data.append({
            "id": b.id, "name": b.name, "level": b.level, "hp": b.hp,
            "atk": b.atk, "df": b.df, "exp_reward": b.exp_reward,
            "gold_reward": b.gold_reward, "diamond_reward": b.diamond_reward,
            "color": b.color, "desc": b.desc, "tier": b.tier,
            "item_rewards": b.item_rewards or [],
        })
    return schemas.ApiResult(data=data)
