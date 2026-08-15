# -*- coding: utf-8 -*-
"""抽奖系统(去重 + 保底 + 重复转碎片)"""
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

# 稀有度等级(用于保底判断)
RARITY_RANK = {"common": 0, "rare": 1, "epic": 2, "legend": 3, "myth": 4}
# 重复装备转碎片数量(按稀有度)
DUPLICATE_SHARDS = {"common": 5, "rare": 20, "epic": 50, "legend": 150, "myth": 400}


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


def _player_owned_items(db, player_id):
    """玩家已拥有的装备类物品(weapon/armor/skin)集合"""
    rows = db.query(models.PlayerItem).filter_by(player_id=player_id).all()
    owned = set()
    for pi in rows:
        if pi.item and pi.item.type in ("weapon", "armor", "skin"):
            owned.add(pi.item_id)
    return owned


def _pick_weighted(gi_list, total_w, owned_ids, pity_rarity_rank=0):
    """加权随机选一个物品。
    pity_rarity_rank>0 时,只从稀有度>=该等级的物品中选(保底)。"""
    candidates = gi_list
    if pity_rarity_rank > 0:
        candidates = [x for x in gi_list if x.item and RARITY_RANK.get(x.item.rarity, 0) >= pity_rarity_rank]
        if not candidates:
            candidates = gi_list  # 没有足够稀有的,回退全池
    total = sum(x.weight for x in candidates)
    r = random.randint(1, total)
    acc = 0
    for x in candidates:
        acc += x.weight
        if r <= acc:
            return x
    return candidates[-1]


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

    owned_ids = _player_owned_items(db, player.id)
    results = []
    # 保底计数:连续 N 次没出 epic+ 则下一次必出
    pity_counter = 0
    PITY_THRESHOLD = 8  # 每8次未出史诗+,下一次必出史诗+

    for i in range(times):
        # 判断是否触发保底(十连最后一抽 + 之前全没出 epic+)
        trigger_pity = (pity_counter >= PITY_THRESHOLD) or (times == 10 and i == 9 and pity_counter >= 5)
        chosen = _pick_weighted(gi_list, total_w, owned_ids,
                                pity_rarity_rank=2 if trigger_pity else 0)
        item = chosen.item
        is_duplicate = item and item.type in ("weapon", "armor", "skin") and chosen.item_id in owned_ids

        if is_duplicate:
            # 重复装备转碎片(给金币补偿)
            shard_gold = DUPLICATE_SHARDS.get(item.rarity, 10)
            player.gold += shard_gold
            results.append(schemas.GachaResultItem(
                item=item_to_info(item), count=chosen.count, is_new=False,
                note=f"重复,已转为 {shard_gold} 金币",
            ))
        else:
            add_player_item(db, player.id, chosen.item_id, chosen.count)
            if item and item.type in ("weapon", "armor", "skin"):
                owned_ids.add(chosen.item_id)
            results.append(schemas.GachaResultItem(
                item=item_to_info(item), count=chosen.count, is_new=True,
            ))

        # 更新保底计数
        item_rank = RARITY_RANK.get(item.rarity, 0) if item else 0
        if item_rank >= 2:  # epic+
            pity_counter = 0
        else:
            pity_counter += 1

    player.gacha_count += times
    db.commit()
    return schemas.ApiResult(data={
        "results": [r.dict() for r in results],
        "cost_type": pool.cost_type, "cost_amount": cost,
        "player": build_player_info(db, player),
    })
