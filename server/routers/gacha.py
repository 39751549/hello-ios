# -*- coding: utf-8 -*-
"""抽奖系统"""
import random
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from deps import get_current_player
from routers.player import build_player_info
import models
import schemas
from utils import add_player_item, item_to_info

router = APIRouter(prefix="/api/gacha", tags=["gacha"])


@router.get("/pools", response_model=schemas.ApiResult)
def pools(db: Session = Depends(get_db)):
    ps = db.query(models.GachaPool).filter_by(enabled=True).all()
    data = []
    for p in ps:
        gi = db.query(models.GachaItem).filter_by(pool_id=p.id).all()
        total_w = sum(x.weight for x in gi)
        data.append({
            "id": p.id, "name": p.name, "cost_type": p.cost_type,
            "cost_once": p.cost_once, "cost_ten": p.cost_ten, "desc": p.desc,
            "total_weight": total_w,
            "items": [{"item": item_to_info(x.item).dict(), "weight": x.weight} for x in gi if x.item],
        })
    return schemas.ApiResult(data=data)


@router.post("/draw", response_model=schemas.ApiResult)
def draw(req: schemas.GachaIn, player: models.Player = Depends(get_current_player), db: Session = Depends(get_db)):
    pool = db.query(models.GachaPool).filter_by(id=req.pool_id, enabled=True).first()
    if not pool:
        raise HTTPException(404, "奖池不存在")
    times = 10 if req.times >= 10 else 1
    if times == 10:
        cost = pool.cost_ten
    else:
        cost = pool.cost_once
    if pool.cost_type == "gold":
        if player.gold < cost:
            raise HTTPException(400, "金币不足")
        player.gold -= cost
    else:
        if player.diamond < cost:
            raise HTTPException(400, "钻石不足")
        player.diamond -= cost

    gi_list = db.query(models.GachaItem).filter_by(pool_id=pool.id).all()
    if not gi_list:
        raise HTTPException(400, "奖池为空")
    total_w = sum(x.weight for x in gi_list)

    results = []
    for _ in range(times):
        r = random.randint(1, total_w)
        acc = 0
        chosen = gi_list[0]
        for x in gi_list:
            acc += x.weight
            if r <= acc:
                chosen = x
                break
        add_player_item(db, player.id, chosen.item_id, chosen.count)
        # 判断是否新(简化:count刚等于chosen.count视为新)
        results.append(schemas.GachaResultItem(
            item=item_to_info(chosen.item), count=chosen.count, is_new=True,
        ))

    player.gacha_count += times
    db.commit()
    return schemas.ApiResult(data={
        "results": [r.dict() for r in results],
        "cost_type": pool.cost_type, "cost_amount": cost,
        "player": build_player_info(db, player),
    })
