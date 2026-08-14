# -*- coding: utf-8 -*-
"""战斗系统"""
import random
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from deps import get_current_player
from routers.player import build_player_info
import models
import schemas
import game_logic
from utils import add_player_item

router = APIRouter(prefix="/api/battle", tags=["battle"])


@router.post("/fight", response_model=schemas.ApiResult)
def fight(req: schemas.BattleIn, player: models.Player = Depends(get_current_player), db: Session = Depends(get_db)):
    items = db.query(models.PlayerItem).filter_by(player_id=player.id).all()
    p_atk = game_logic.total_atk(player, items)
    p_df = game_logic.total_df(player, items)
    p_hp = game_logic.total_hp(player, items)
    if player.cur_hp <= 0:
        player.cur_hp = 1
    if player.cur_hp > p_hp:
        player.cur_hp = p_hp
    cur_hp = player.cur_hp

    is_boss = False
    if req.boss_id:
        boss = db.query(models.Boss).filter_by(id=req.boss_id).first()
        if not boss:
            raise HTTPException(404, "Boss 不存在")
        e_name = boss.name
        e_hp, e_atk, e_df = boss.hp, boss.atk, boss.df
        exp_reward = boss.exp_reward
        gold_reward = boss.gold_reward
        diamond_reward = boss.diamond_reward
        drops_config = boss.item_rewards or []
        is_boss = True
    else:
        lvl = max(req.enemy_level or player.level, 1)
        e_name = f"Lv.{lvl} 野怪"
        e_hp = 120 * lvl + 80
        e_atk = 10 * lvl + 5
        e_df = 3 * lvl + 2
        exp_reward = 35 * lvl
        gold_reward = 50 * lvl
        diamond_reward = 0
        # 普通怪随机掉落小血药
        hp_s = db.query(models.Item).filter_by(code="c_hp_s").first()
        drops_config = [{"item_id": hp_s.id, "count": 1, "rate": 0.25}] if hp_s else []

    win, rounds, hp_left, log = game_logic.calc_battle(p_atk, p_df, cur_hp, e_atk, e_df, e_hp)

    result = schemas.BattleResult(
        win=win, rounds=rounds, hp_left=max(hp_left, 0), log=log, enemy_name=e_name,
    )

    if win:
        leveled = game_logic.add_exp(player, exp_reward)
        player.gold += gold_reward
        player.diamond += diamond_reward
        drops = game_logic.roll_drops(drops_config)
        for d in drops:
            add_player_item(db, player.id, d["item_id"], d["count"])
        player.cur_hp = min(max(hp_left, 1), p_hp)
        player.kill_count += 1
        if is_boss:
            player.boss_kill_count += 1
        result.exp_gain = exp_reward
        result.gold_gain = gold_reward
        result.diamond_gain = diamond_reward
        result.drops = drops
        result.leveled_up = leveled
    else:
        player.cur_hp = max(cur_hp // 2, 1)

    db.add(models.BattleRecord(
        player_id=player.id, boss_id=req.boss_id, enemy_name=e_name, win=win,
        exp_gain=result.exp_gain, gold_gain=result.gold_gain,
        diamond_gain=result.diamond_gain, items_gain=drops if win else [],
    ))
    db.commit()
    result_data = result.dict()
    result_data["player"] = build_player_info(db, player)
    return schemas.ApiResult(data=result_data)
