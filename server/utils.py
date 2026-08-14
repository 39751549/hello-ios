# -*- coding: utf-8 -*-
"""通用工具"""
from sqlalchemy.orm import Session
import models


def add_player_item(db: Session, player_id: int, item_id: int, count: int = 1):
    """给玩家增加物品,已有则累加。返回 PlayerItem"""
    pi = db.query(models.PlayerItem).filter_by(player_id=player_id, item_id=item_id).first()
    if pi:
        pi.count += count
    else:
        pi = models.PlayerItem(player_id=player_id, item_id=item_id, count=count)
        db.add(pi)
    db.flush()
    return pi


def item_to_info(item: models.Item):
    from schemas import ItemInfo
    return ItemInfo(
        id=item.id, code=item.code, name=item.name, type=item.type, rarity=item.rarity,
        atk=item.atk, df=item.df, hp=item.hp, price_gold=item.price_gold,
        price_diamond=item.price_diamond, color=item.color, desc=item.desc,
    )
