# -*- coding: utf-8 -*-
"""商店"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from deps import get_current_player
from routers.player import build_player_info
import models
import schemas
from utils import add_player_item, item_to_info

router = APIRouter(prefix="/api/shop", tags=["shop"])


@router.get("/items", response_model=schemas.ApiResult)
def list_items(db: Session = Depends(get_db)):
    # 只列出有价格的物品(可购买)
    its = db.query(models.Item).filter(
        (models.Item.price_gold > 0) | (models.Item.price_diamond > 0)
    ).all()
    return schemas.ApiResult(data=[item_to_info(i).dict() for i in its])


@router.post("/buy", response_model=schemas.ApiResult)
def buy(req: schemas.BuyIn, player: models.Player = Depends(get_current_player), db: Session = Depends(get_db)):
    if req.count < 1:
        raise HTTPException(400, "数量无效")
    item = db.query(models.Item).filter_by(id=req.item_id).first()
    if not item:
        raise HTTPException(404, "物品不存在")

    # 优先用钻石买,其次金币
    if item.price_diamond > 0:
        cost = item.price_diamond * req.count
        if player.diamond < cost:
            raise HTTPException(400, "钻石不足")
        player.diamond -= cost
    elif item.price_gold > 0:
        cost = item.price_gold * req.count
        if player.gold < cost:
            raise HTTPException(400, "金币不足")
        player.gold -= cost
    else:
        raise HTTPException(400, "该物品不可购买")

    add_player_item(db, player.id, item.id, req.count)
    db.commit()
    return schemas.ApiResult(msg=f"购买 {item.name} x{req.count}", data=build_player_info(db, player))
