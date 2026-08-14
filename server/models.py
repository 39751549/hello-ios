# -*- coding: utf-8 -*-
"""数据模型 (SQLAlchemy ORM)"""
from datetime import datetime
from sqlalchemy import (
    Column, Integer, BigInteger, String, Float, Boolean, Text, DateTime,
    ForeignKey, UniqueConstraint, Index, JSON,
)
from sqlalchemy.orm import relationship
from database import Base


# ============ 账号 ============
class User(Base):
    __tablename__ = "users"
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    username = Column(String(64), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_login = Column(DateTime, default=datetime.utcnow)
    player = relationship("Player", uselist=False, back_populates="user")


# ============ 玩家角色 ============
class Player(Base):
    __tablename__ = "players"
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id"), unique=True, nullable=False)
    nickname = Column(String(64), nullable=False)
    level = Column(Integer, default=1)
    exp = Column(BigInteger, default=0)
    gold = Column(BigInteger, default=0)        # 游戏币
    diamond = Column(BigInteger, default=0)     # 充值币
    vip = Column(Integer, default=0)
    hp = Column(Integer, default=200)
    atk = Column(Integer, default=20)
    df = Column(Integer, default=10)            # def 是保留字,用 df
    cur_hp = Column(Integer, default=200)
    # 装备槽: weapon / armor / skin (存 item_id)
    equip_weapon = Column(Integer, nullable=True)
    equip_armor = Column(Integer, nullable=True)
    equip_skin = Column(Integer, nullable=True)
    # 统计
    kill_count = Column(Integer, default=0)
    boss_kill_count = Column(Integer, default=0)
    gacha_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    user = relationship("User", back_populates="player")
    items = relationship("PlayerItem", back_populates="player", cascade="all, delete-orphan")


# ============ 物品配置 ============
class Item(Base):
    __tablename__ = "items"
    id = Column(Integer, primary_key=True, autoincrement=True)
    code = Column(String(64), unique=True, nullable=False)          # 唯一代码
    name = Column(String(64), nullable=False)
    type = Column(String(32), nullable=False)  # weapon/armor/skin/consumable/material
    rarity = Column(String(16), default="common")  # common/rare/epic/legend/myth
    atk = Column(Integer, default=0)
    df = Column(Integer, default=0)
    hp = Column(Integer, default=0)
    price_gold = Column(BigInteger, default=0)
    price_diamond = Column(BigInteger, default=0)
    color = Column(String(16), default="#cccccc")   # UI 颜色
    desc = Column(String(255), default="")


# ============ 玩家物品 ============
class PlayerItem(Base):
    __tablename__ = "player_items"
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    player_id = Column(BigInteger, ForeignKey("players.id"), nullable=False, index=True)
    item_id = Column(Integer, ForeignKey("items.id"), nullable=False)
    count = Column(Integer, default=1)
    obtained_at = Column(DateTime, default=datetime.utcnow)
    player = relationship("Player", back_populates="items")
    item = relationship("Item")
    __table_args__ = (Index("idx_player_item", "player_id", "item_id"),)


# ============ 奖池 ============
class GachaPool(Base):
    __tablename__ = "gacha_pools"
    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(64), nullable=False)
    cost_type = Column(String(16), nullable=False)   # gold / diamond
    cost_once = Column(Integer, default=0)
    cost_ten = Column(Integer, default=0)
    desc = Column(String(255), default="")
    enabled = Column(Boolean, default=True)


class GachaItem(Base):
    __tablename__ = "gacha_items"
    id = Column(Integer, primary_key=True, autoincrement=True)
    pool_id = Column(Integer, ForeignKey("gacha_pools.id"), nullable=False, index=True)
    item_id = Column(Integer, ForeignKey("items.id"), nullable=False)
    weight = Column(Integer, default=1)
    count = Column(Integer, default=1)
    item = relationship("Item")


# ============ Boss ============
class Boss(Base):
    __tablename__ = "bosses"
    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(64), nullable=False)
    level = Column(Integer, default=1)
    hp = Column(Integer, default=500)
    atk = Column(Integer, default=30)
    df = Column(Integer, default=10)
    exp_reward = Column(BigInteger, default=100)
    gold_reward = Column(BigInteger, default=200)
    diamond_reward = Column(Integer, default=0)
    item_rewards = Column(JSON, default=list)   # [{item_id, count, rate}]
    color = Column(String(16), default="#ff5555")
    desc = Column(String(255), default="")
    tier = Column(Integer, default=1)           # 难度档位


# ============ 战斗记录 ============
class BattleRecord(Base):
    __tablename__ = "battle_records"
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    player_id = Column(BigInteger, ForeignKey("players.id"), nullable=False, index=True)
    boss_id = Column(Integer, nullable=True)       # null = 普通怪
    enemy_name = Column(String(64), default="")
    win = Column(Boolean, default=False)
    exp_gain = Column(BigInteger, default=0)
    gold_gain = Column(BigInteger, default=0)
    diamond_gain = Column(Integer, default=0)
    items_gain = Column(JSON, default=list)
    created_at = Column(DateTime, default=datetime.utcnow)


# ============ 充值记录 ============
class RechargeRecord(Base):
    __tablename__ = "recharge_records"
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    player_id = Column(BigInteger, ForeignKey("players.id"), nullable=False, index=True)
    diamond = Column(BigInteger, default=0)
    amount_yuan = Column(Float, default=0)
    gm_user = Column(String(64), default="")
    remark = Column(String(255), default="")
    created_at = Column(DateTime, default=datetime.utcnow)


# ============ GM 账号 ============
class GmUser(Base):
    __tablename__ = "gm_users"
    id = Column(Integer, primary_key=True, autoincrement=True)
    username = Column(String(64), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)


# ============ GM 操作日志 ============
class GmLog(Base):
    __tablename__ = "gm_logs"
    id = Column(BigInteger, primary_key=True, autoincrement=True)
    gm_user = Column(String(64), nullable=False)
    action = Column(String(64), nullable=False)
    target = Column(String(128), default="")
    detail = Column(Text, default="")
    created_at = Column(DateTime, default=datetime.utcnow)
