# -*- coding: utf-8 -*-
"""游戏核心逻辑:经验、属性、战斗"""
import random
from config import EXP_BASE, EXP_FACTOR, MAX_LEVEL
import models


def exp_to_next(level: int) -> int:
    """升到 level+1 所需经验"""
    return int(EXP_BASE * (level ** EXP_FACTOR))


def total_atk(player: models.Player, items: list) -> int:
    base = player.atk
    for pi in items:
        if pi.item and _is_equipped(player, pi.item.type) == pi.item_id:
            base += pi.item.atk
    return base


def total_df(player: models.Player, items: list) -> int:
    base = player.df
    for pi in items:
        if pi.item and _is_equipped(player, pi.item.type) == pi.item_id:
            base += pi.item.df
    return base


def total_hp(player: models.Player, items: list) -> int:
    base = player.hp
    for pi in items:
        if pi.item and _is_equipped(player, pi.item.type) == pi.item_id:
            base += pi.item.hp
    return base


def _is_equipped(player, item_type):
    if item_type == "weapon":
        return player.equip_weapon
    if item_type == "armor":
        return player.equip_armor
    if item_type == "skin":
        return player.equip_skin
    return None


def equipped_items(player: models.Player) -> dict:
    return {
        "weapon": player.equip_weapon,
        "armor": player.equip_armor,
        "skin": player.equip_skin,
    }


def add_exp(player: models.Player, exp_gain: int) -> list:
    """加经验并升级,返回升级信息"""
    player.exp += exp_gain
    leveled = []
    while player.level < MAX_LEVEL and player.exp >= exp_to_next(player.level):
        player.exp -= exp_to_next(player.level)
        player.level += 1
        # 每级提升基础属性
        player.hp += 20
        player.atk += 3
        player.df += 2
        leveled.append(player.level)
    if player.level >= MAX_LEVEL:
        player.exp = 0
    # 升级后回满血
    if leveled:
        player.cur_hp = player.hp
    return leveled


def calc_battle(p_atk, p_df, p_hp, e_atk, e_df, e_hp, p_first=True):
    """回合制战斗结算,返回 (win, rounds, p_hp_left, log)
    增强:暴击率25%、连击加成、更大伤害波动、闪避、暴击致命"""
    p_hp_cur = p_hp
    e_hp_cur = e_hp
    log = []
    combo = 0  # 连击数
    max_combo = 0
    total_crit = 0
    for r in range(1, 80):
        if p_first:
            # 玩家攻击
            base = max(int(p_atk * random.uniform(0.85, 1.25)) - e_df, 1)
            crit = random.random() < 0.25  # 暴击率25%
            dodge = random.random() < 0.05  # 5%闪避
            if dodge:
                log.append(f"回合{r}: 敌人闪避了你的攻击!")
            else:
                if crit:
                    base = int(base * 2.2)
                    total_crit += 1
                    combo += 1
                else:
                    combo = 0
                # 连击加成:连续暴击伤害递增
                if combo >= 2:
                    base = int(base * (1 + 0.15 * combo))
                max_combo = max(max_combo, combo)
                e_hp_cur -= base
                tag = ""
                if crit:
                    tag = f"(暴击! 连击x{combo})" if combo >= 2 else "(暴击!)"
                log.append(f"回合{r}: 你造成 {base}{tag} 伤害,敌剩余 {max(e_hp_cur,0)}")
                if e_hp_cur <= 0:
                    log.append(f"战斗结束! 最高连击 {max_combo}, 暴击 {total_crit} 次")
                    return True, r, p_hp_cur, log
            # 敌人攻击
            edmg = max(int(e_atk * random.uniform(0.85, 1.1)) - p_df, 1)
            p_dodge = random.random() < 0.08  # 玩家8%闪避
            if p_dodge:
                log.append(f"回合{r}: 你闪避了敌人攻击!")
            else:
                p_hp_cur -= edmg
                log.append(f"回合{r}: 敌造成 {edmg} 伤害,你剩余 {max(p_hp_cur,0)}")
                if p_hp_cur <= 0:
                    return False, r, 0, log
        else:
            edmg = max(int(e_atk * random.uniform(0.85, 1.1)) - p_df, 1)
            p_hp_cur -= edmg
            log.append(f"回合{r}: 敌造成 {edmg} 伤害,你剩余 {max(p_hp_cur,0)}")
            if p_hp_cur <= 0:
                return False, r, 0, log
            base = max(int(p_atk * random.uniform(0.85, 1.25)) - e_df, 1)
            crit = random.random() < 0.25
            if crit:
                base = int(base * 2.2)
                total_crit += 1
                combo += 1
            else:
                combo = 0
            if combo >= 2:
                base = int(base * (1 + 0.15 * combo))
            max_combo = max(max_combo, combo)
            e_hp_cur -= base
            tag = ""
            if crit:
                tag = f"(暴击! 连击x{combo})" if combo >= 2 else "(暴击!)"
            log.append(f"回合{r}: 你造成 {base}{tag} 伤害,敌剩余 {max(e_hp_cur,0)}")
            if e_hp_cur <= 0:
                log.append(f"战斗结束! 最高连击 {max_combo}, 暴击 {total_crit} 次")
                return True, r, p_hp_cur, log
    return False, 80, p_hp_cur, log


def roll_drops(item_rewards: list) -> list:
    """根据掉落配置随机掉落,返回 [{item_id, count}]"""
    drops = []
    for r in item_rewards or []:
        if r.get("item_id") and random.random() < r.get("rate", 0):
            drops.append({"item_id": r["item_id"], "count": r.get("count", 1)})
    return drops


RARITY_ORDER = {"common": 0, "rare": 1, "epic": 2, "legend": 3, "myth": 4}
RARITY_NAME = {"common": "普通", "rare": "稀有", "epic": "史诗", "legend": "传说", "myth": "神话"}
TYPE_NAME = {"weapon": "武器", "armor": "防具", "skin": "皮肤", "consumable": "消耗品", "material": "材料"}
