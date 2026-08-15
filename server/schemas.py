# -*- coding: utf-8 -*-
"""API 请求/响应数据结构 (Pydantic)"""
from typing import Optional, List, Any
from pydantic import BaseModel


# ---- 账号 ----
class RegisterIn(BaseModel):
    username: str
    password: str
    nickname: Optional[str] = None


class LoginIn(BaseModel):
    username: str
    password: str


class TokenOut(BaseModel):
    token: str
    player_id: int


# ---- 通用 ----
class ApiResult(BaseModel):
    code: int = 0          # 0=成功, 非0=失败
    msg: str = "ok"
    data: Any = None


class ItemInfo(BaseModel):
    id: int
    code: str
    name: str
    type: str
    rarity: str
    atk: int = 0
    df: int = 0
    hp: int = 0
    price_gold: int = 0
    price_diamond: int = 0
    color: str = "#cccccc"
    desc: str = ""


class PlayerItemInfo(BaseModel):
    id: int
    item: ItemInfo
    count: int


class PlayerInfo(BaseModel):
    id: int
    nickname: str
    level: int
    exp: int
    exp_next: int
    gold: int
    diamond: int
    vip: int
    hp: int
    atk: int
    df: int
    cur_hp: int
    total_atk: int
    total_df: int
    total_hp: int
    kill_count: int
    boss_kill_count: int
    gacha_count: int
    equip: dict
    items: List[PlayerItemInfo] = []


# ---- 战斗 ----
class BattleIn(BaseModel):
    boss_id: Optional[int] = None     # None = 普通怪
    enemy_level: Optional[int] = None


class BattleResult(BaseModel):
    win: bool
    rounds: int
    hp_left: int
    exp_gain: int = 0
    gold_gain: int = 0
    diamond_gain: int = 0
    drops: List[dict] = []
    log: List[str] = []
    leveled_up: List[int] = []
    enemy_name: str = ""


# ---- 抽奖 ----
class GachaIn(BaseModel):
    pool_id: int
    times: int = 1     # 1 或 10


class GachaResultItem(BaseModel):
    item: ItemInfo
    count: int
    is_new: bool = True
    note: str = ""


class GachaResult(BaseModel):
    results: List[GachaResultItem]
    cost_type: str
    cost_amount: int


# ---- 商店 ----
class BuyIn(BaseModel):
    item_id: int
    count: int = 1


class EquipIn(BaseModel):
    player_item_id: int


class UseItemIn(BaseModel):
    player_item_id: int
    count: int = 1


# ---- GM ----
class GmLoginIn(BaseModel):
    username: str
    password: str


class GmRechargeIn(BaseModel):
    player_id: int
    diamond: int
    amount_yuan: float = 0
    remark: str = ""


class GmGiveItemIn(BaseModel):
    player_id: int
    item_id: int
    count: int = 1


class GmSetLevelIn(BaseModel):
    player_id: int
    level: int


class GmSetCurrencyIn(BaseModel):
    player_id: int
    gold: Optional[int] = None
    diamond: Optional[int] = None


class GmSetConfigIn(BaseModel):
    key: str
    value: str


class GmAddConfigIn(BaseModel):
    key: str
    value: str
    desc: str = ""
