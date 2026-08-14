# -*- coding: utf-8 -*-
"""玩家数据 / 背包 / 装备 / 消耗品"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from deps import get_current_player
import models
import schemas
import game_logic

router = APIRouter(prefix="/api/player", tags=["player"])


def build_player_info(db: Session, player: models.Player) -> schemas.PlayerInfo:
    items = db.query(models.PlayerItem).filter_by(player_id=player.id).all()
    t_atk = game_logic.total_atk(player, items)
    t_df = game_logic.total_df(player, items)
    t_hp = game_logic.total_hp(player, items)
    return schemas.PlayerInfo(
        id=player.id, nickname=player.nickname, level=player.level,
        exp=player.exp, exp_next=game_logic.exp_to_next(player.level),
        gold=player.gold, diamond=player.diamond, vip=player.vip,
        hp=player.hp, atk=player.atk, df=player.df, cur_hp=player.cur_hp,
        total_atk=t_atk, total_df=t_df, total_hp=t_hp,
        kill_count=player.kill_count, boss_kill_count=player.boss_kill_count,
        gacha_count=player.gacha_count,
        equip={
            "weapon": player.equip_weapon, "armor": player.equip_armor, "skin": player.equip_skin,
        },
        items=[schemas.PlayerItemInfo(
            id=pi.id, count=pi.count,
            item=schemas.ItemInfo(
                id=pi.item.id, code=pi.item.code, name=pi.item.name, type=pi.item.type,
                rarity=pi.item.rarity, atk=pi.item.atk, df=pi.item.df, hp=pi.item.hp,
                price_gold=pi.item.price_gold, price_diamond=pi.item.price_diamond,
                color=pi.item.color, desc=pi.item.desc,
            )
        ) for pi in items if pi.item],
    )


@router.get("/me", response_model=schemas.ApiResult)
def me(player: models.Player = Depends(get_current_player), db: Session = Depends(get_db)):
    return schemas.ApiResult(data=build_player_info(db, player))


@router.post("/heal", response_model=schemas.ApiResult)
def heal(player: models.Player = Depends(get_current_player), db: Session = Depends(get_db)):
    items = db.query(models.PlayerItem).filter_by(player_id=player.id).all()
    t_hp = game_logic.total_hp(player, items)
    if player.cur_hp >= t_hp:
        raise HTTPException(400, "生命值已满")
    cost = max((t_hp - player.cur_hp) // 2, 10)
    if player.gold < cost:
        raise HTTPException(400, f"金币不足,需要 {cost}")
    player.gold -= cost
    player.cur_hp = t_hp
    db.commit()
    return schemas.ApiResult(msg=f"已回满血,消耗 {cost} 金币", data=build_player_info(db, player))


@router.post("/equip", response_model=schemas.ApiResult)
def equip(req: schemas.EquipIn, player: models.Player = Depends(get_current_player), db: Session = Depends(get_db)):
    pi = db.query(models.PlayerItem).filter_by(id=req.player_item_id, player_id=player.id).first()
    if not pi or not pi.item:
        raise HTTPException(400, "物品不存在")
    if pi.item.type not in ("weapon", "armor", "skin"):
        raise HTTPException(400, "该物品不可装备")
    if pi.count < 1:
        raise HTTPException(400, "物品数量不足")
    if pi.item.type == "weapon":
        player.equip_weapon = pi.item.id
    elif pi.item.type == "armor":
        player.equip_armor = pi.item.id
    else:
        player.equip_skin = pi.item.id
    db.commit()
    return schemas.ApiResult(msg=f"已装备 {pi.item.name}", data=build_player_info(db, player))


@router.post("/unequip", response_model=schemas.ApiResult)
def unequip(req: schemas.EquipIn, player: models.Player = Depends(get_current_player), db: Session = Depends(get_db)):
    # 用 item_id 卸下(前端传装备槽的item_id,这里复用 player_item_id 字段当 item_id)
    item_id = req.player_item_id
    if player.equip_weapon == item_id:
        player.equip_weapon = None
    elif player.equip_armor == item_id:
        player.equip_armor = None
    elif player.equip_skin == item_id:
        player.equip_skin = None
    else:
        raise HTTPException(400, "该物品未装备")
    db.commit()
    return schemas.ApiResult(msg="已卸下", data=build_player_info(db, player))


@router.post("/use_item", response_model=schemas.ApiResult)
def use_item(req: schemas.UseItemIn, player: models.Player = Depends(get_current_player), db: Session = Depends(get_db)):
    pi = db.query(models.PlayerItem).filter_by(id=req.player_item_id, player_id=player.id).first()
    if not pi or not pi.item:
        raise HTTPException(400, "物品不存在")
    if pi.item.type != "consumable":
        raise HTTPException(400, "非消耗品")
    if pi.count < req.count:
        raise HTTPException(400, "数量不足")
    items = db.query(models.PlayerItem).filter_by(player_id=player.id).all()
    t_hp = game_logic.total_hp(player, items)
    # 效果
    code = pi.item.code
    for _ in range(req.count):
        if code == "c_hp_s":
            player.cur_hp = min(t_hp, player.cur_hp + 100)
        elif code == "c_hp_l":
            player.cur_hp = min(t_hp, player.cur_hp + 500)
        elif code == "c_atk":
            player.atk += 2   # 永久小幅提升
    pi.count -= req.count
    if pi.count <= 0:
        db.delete(pi)
    db.commit()
    return schemas.ApiResult(msg=f"使用了 {pi.item.name} x{req.count}", data=build_player_info(db, player))
