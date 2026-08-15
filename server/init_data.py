# -*- coding: utf-8 -*-
"""建表 + 初始游戏数据导入"""
from database import engine, SessionLocal, Base
import models
from security import hash_password
from config import GM_DEFAULT_USER, GM_DEFAULT_PASSWORD, INIT_LEVEL, INIT_GOLD, INIT_DIAMOND, INIT_HP, INIT_ATK, INIT_DEF

# ============ 物品配置 ============
# (code, name, type, rarity, atk, df, hp, price_gold, price_diamond, color, desc)
ITEMS = [
    # ---- 武器 ----
    ("w_iron",     "铁剑",       "weapon", "common",  12, 0, 0,    200, 0,   "#9aa0a6", "新手铁剑"),
    ("w_steel",    "精钢长剑",   "weapon", "rare",    30, 0, 0,    800, 0,   "#4a9eff", "锋利的精钢剑"),
    ("w_flame",    "烈焰之刃",   "weapon", "epic",    70, 0, 50,   0,   200, "#ff7043", "附带火焰之力"),
    ("w_dragon",   "龙魂巨剑",   "weapon", "legend",  140,0, 120,  0,   600, "#ab47bc", "蕴含龙魂"),
    ("w_god",      "神灭·天罚",  "weapon", "myth",    280,20,300,  0,   1500,"#ffd54f", "灭世神兵"),
    ("w_void",     "虚空裂痕",   "weapon", "myth",    320,30,400,  0,   2000,"#ce93d8", "撕裂虚空"),
    ("w_thunder",  "雷霆之怒",   "weapon", "legend",  160,10,80,   0,   700, "#ffd54f", "雷霆万钧"),
    ("w_frost",    "冰封之刃",   "weapon", "epic",    75, 5, 60,   0,   220, "#26c6da", "寒冰刺骨"),
    # ---- 防具 ----
    ("a_cloth",    "布衣",       "armor",  "common",  0,  6, 50,   150, 0,   "#9aa0a6", "普通布衣"),
    ("a_leather",  "皮甲",       "armor",  "rare",    0,  16,120,  600, 0,   "#4a9eff", "坚韧皮甲"),
    ("a_iron",     "玄铁甲",     "armor",  "epic",    0,  42,300,  0,   200, "#ff7043", "玄铁锻造"),
    ("a_dragon",   "龙鳞战甲",   "armor",  "legend",  0,  95,700,  0,   600, "#ab47bc", "龙鳞制成"),
    ("a_divine",   "神佑圣衣",   "armor",  "myth",    30, 200,1500,0,   1500,"#ffd54f", "神明护佑"),
    ("a_phantom",  "幻影披风",   "armor",  "epic",    10, 35,250,  0,   250, "#7c4dff", "幻影迷踪"),
    # ---- 皮肤 ----
    ("s_novice",   "新手装",     "skin",   "common",  0,  0, 0,    0,   0,   "#9aa0a6", "默认外观"),
    ("s_shadow",   "暗影刺客",   "skin",   "rare",    5,  5, 50,   0,   150, "#4a9eff", "暗影之力"),
    ("s_flame",    "烈焰战神",   "skin",   "epic",    10, 10,100,  0,   300, "#ff7043", "浴火战神"),
    ("s_frost",    "冰霜女王",   "skin",   "legend",  15, 15,200,  0,   500, "#26c6da", "冰封万物"),
    ("s_gold",     "黄金帝王",   "skin",   "myth",    25, 25,300,  0,   1000,"#ffd54f", "至高荣耀"),
    ("s_void",     "虚空之翼",   "skin",   "myth",    30, 30,400,  0,   1200,"#ce93d8", "虚空之力"),
    # ---- 消耗品 ----
    ("c_hp_s",     "小血药",     "consumable", "common", 0, 0, 0,  50,  0,   "#ef5350", "回复100HP"),
    ("c_hp_l",     "大血药",     "consumable", "rare",   0, 0, 0,  200, 0,   "#ef5350", "回复500HP"),
    ("c_atk",      "狂暴药水",   "consumable", "epic",   0, 0, 0,  0,   50,  "#ff7043", "临时攻击+20"),
    ("c_def",      "铁甲药水",   "consumable", "rare",   0, 0, 0,  0,   30,  "#4a9eff", "临时防御+15"),
]

# ============ Boss 配置 ============
# (name, level, hp, atk, df, exp, gold, diamond, color, desc, tier, item_rewards)
# 每个BOSS都有掉落,等级越高掉落越好
BOSSES = [
    ("哥布林首领",   5,   800,    25,  5,   80,    150,   0, "#8bc34a", "森林里的恶霸",      1,
     [("w_iron",0.25,1),("a_cloth",0.20,1),("c_hp_s",0.40,2)]),
    ("野猪王",       8,   1500,   35,  8,   150,   280,   0, "#a1887f", "凶猛的野猪",        1,
     [("w_steel",0.15,1),("a_leather",0.12,1),("c_hp_l",0.30,1)]),
    ("石巨人",       12,  3000,   50,  20,  280,   500,   0, "#90a4ae", "坚不可摧",          1,
     [("a_iron",0.18,1),("w_steel",0.12,1),("c_def",0.25,1)]),
    ("暗影刺客",     16,  5000,   80,  15,  450,   800,   1, "#5c6bc0", "暗影中的杀手",      2,
     [("w_frost",0.15,1),("a_phantom",0.12,1),("s_shadow",0.08,1)]),
    ("火焰恶魔",     22,  9000,   120, 30,  800,   1400,  2, "#ff7043", "烈焰化身",          2,
     [("w_flame",0.18,1),("s_flame",0.10,1),("c_atk",0.30,2)]),
    ("冰霜巨龙",     30,  18000,  170, 50,  1500,  2600,  3, "#26c6da", "冰封巨龙",          3,
     [("w_dragon",0.12,1),("a_dragon",0.10,1),("s_frost",0.08,1)]),
    ("深渊魔王",     40,  35000,  240, 80,  2800,  4800,  5, "#ab47bc", "深渊降临",          3,
     [("w_dragon",0.15,1),("a_dragon",0.12,1),("w_thunder",0.08,1)]),
    ("远古泰坦",     55,  70000,  340, 130, 5000,  8500,  8, "#8d6e63", "远古之力",          4,
     [("w_god",0.10,1),("a_divine",0.08,1),("w_thunder",0.15,1)]),
    ("虚空之主",     70,  140000, 480, 200, 9000,  15000, 12,"#ce93d8", "虚空主宰",          4,
     [("w_void",0.10,1),("a_divine",0.10,1),("s_void",0.08,1)]),
    ("世界BOSS·混沌",90,  300000, 700, 320, 18000, 30000, 20,"#ffd54f", "混沌之源",          5,
     [("w_void",0.15,1),("w_god",0.15,1),("s_gold",0.10,1),("s_void",0.10,1)]),
    ("终焉之神",     100, 600000, 1000,500, 35000, 60000, 40,"#e91e63", "终焉降临",          5,
     [("w_void",0.20,1),("s_gold",0.15,1),("a_divine",0.15,1),("s_void",0.12,1)]),
]

# ============ 奖池配置 ============
# (name, cost_type, cost_once, cost_ten, desc, [(item_code, weight, count), ...])
GACHA_POOLS = [
    ("新手装备池(金币)", "gold", 300, 2700, "基础装备,金币抽取", [
        ("w_iron", 25, 1), ("w_steel", 12, 1), ("a_cloth", 25, 1), ("a_leather", 12, 1),
        ("c_hp_s", 20, 3), ("c_hp_l", 8, 1), ("c_def", 8, 1),
    ]),
    ("高级装备池(钻石)", "diamond", 50, 450, "稀有装备+皮肤,钻石抽取", [
        ("w_steel", 20, 1), ("w_flame", 10, 1), ("w_frost", 10, 1), ("w_dragon", 3, 1), ("w_god", 1, 1),
        ("a_leather", 15, 1), ("a_iron", 10, 1), ("a_phantom", 8, 1), ("a_dragon", 3, 1), ("a_divine", 1, 1),
        ("s_shadow", 12, 1), ("s_flame", 6, 1), ("s_frost", 3, 1), ("s_gold", 1, 1),
        ("c_atk", 8, 2),
    ]),
    ("神器池(钻石)", "diamond", 100, 900, "传说神话装备,钻石抽取,保底传说", [
        ("w_dragon", 22, 1), ("w_god", 12, 1), ("w_void", 6, 1), ("w_thunder", 10, 1),
        ("a_dragon", 20, 1), ("a_divine", 10, 1),
        ("s_frost", 12, 1), ("s_gold", 6, 1), ("s_void", 4, 1),
    ]),
]


def _item_code_to_id(db):
    return {it.code: it.id for it in db.query(models.Item).all()}


def init_items(db):
    if db.query(models.Item).count() > 0:
        return
    for code, name, typ, rar, atk, df, hp, pg, pd, color, desc in ITEMS:
        db.add(models.Item(
            code=code, name=name, type=typ, rarity=rar, atk=atk, df=df, hp=hp,
            price_gold=pg, price_diamond=pd, color=color, desc=desc,
        ))
    db.commit()


def init_bosses(db):
    if db.query(models.Boss).count() > 0:
        return
    code2id = _item_code_to_id(db)
    for name, lv, hp, atk, df, exp, gold, dia, color, desc, tier, rewards in BOSSES:
        item_rewards = []
        for r in rewards:
            # 新格式: (item_code, rate, count)
            code, rate, count = r[0], r[1], r[2]
            iid = code2id.get(code)
            if iid:
                item_rewards.append({"item_id": iid, "count": count, "rate": rate})
        db.add(models.Boss(
            name=name, level=lv, hp=hp, atk=atk, df=df,
            exp_reward=exp, gold_reward=gold, diamond_reward=dia,
            color=color, desc=desc, tier=tier, item_rewards=item_rewards,
        ))
    db.commit()


def init_gacha(db):
    if db.query(models.GachaPool).count() > 0:
        return
    code2id = _item_code_to_id(db)
    for name, ct, c1, c10, desc, items in GACHA_POOLS:
        pool = models.GachaPool(name=name, cost_type=ct, cost_once=c1, cost_ten=c10, desc=desc)
        db.add(pool)
        db.commit()
        db.refresh(pool)
        for code, w, cnt in items:
            iid = code2id.get(code)
            if iid:
                db.add(models.GachaItem(pool_id=pool.id, item_id=iid, weight=w, count=cnt))
        db.commit()


def init_gm(db):
    if db.query(models.GmUser).count() == 0:
        db.add(models.GmUser(
            username=GM_DEFAULT_USER,
            password_hash=hash_password(GM_DEFAULT_PASSWORD),
        ))
        db.commit()


# ============ 默认游戏配置(云更新) ============
# (key, value, desc) —— 客户端启动拉取 /api/config,同名 key 覆盖本地默认
DEFAULT_GAME_CONFIG = [
    # 技能 CD(秒)
    ("skill_flame_cd",   "8",   "烈焰斩冷却(秒)"),
    ("skill_aoe_cd",     "10",  "旋风斩冷却(秒)"),
    ("skill_heal_cd",    "15",  "治疗术冷却(秒)"),
    ("skill_ice_cd",     "10",  "冰封术冷却(秒)"),
    ("skill_thunder_cd", "15",  "雷霆术冷却(秒)"),
    ("skill_meteor_cd",  "20",  "陨石术冷却(秒)"),
    # 移动 / 战斗
    ("player_move_speed","4.0", "玩家移动速度"),
    ("monster_respawn",  "5",   "怪物重生间隔(秒)"),
    ("auto_battle_interval", "1.4", "自动挂机攻击间隔(秒)"),
    # 数值
    ("exp_reward_mult",  "1.0", "经验奖励倍率"),
    ("gold_reward_mult", "1.0", "金币奖励倍率"),
    # 功能开关
    ("feature_sound",    "1",   "音效开关 1=开 0=关"),
    ("feature_auto_battle", "1", "自动挂机开关 1=开 0=关"),
    # 公告 / 文案
    ("notice_text",      "欢迎来到幻域神兵!GM 后台可修改此公告。", "登录公告"),
    # 客户端强制升级(>0 时弹窗提示去下载新版本,version_code 比较)
    ("force_update_version", "0", "强制升级最低版本号(0=不强制)"),
    ("update_url",       "",    "新版本下载地址(可留空)"),
]


def init_game_config(db):
    """只插入缺失的 key,已存在的保留 GM 修改"""
    existing = {c.key for c in db.query(models.GameConfig).all()}
    added = 0
    for key, value, desc in DEFAULT_GAME_CONFIG:
        if key not in existing:
            db.add(models.GameConfig(key=key, value=value, desc=desc))
            added += 1
    if added:
        db.commit()
    return added


def init_all():
    print(">>> 创建数据表...")
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        init_items(db)
        print(f"   物品: {db.query(models.Item).count()} 条")
        init_bosses(db)
        print(f"   Boss: {db.query(models.Boss).count()} 条")
        init_gacha(db)
        print(f"   奖池: {db.query(models.GachaPool).count()} 个")
        init_gm(db)
        print(f"   GM账号: {db.query(models.GmUser).count()} 个")
        added = init_game_config(db)
        print(f"   游戏配置: {db.query(models.GameConfig).count()} 条 (新增 {added})")
        print(">>> 初始化完成")
    finally:
        db.close()


if __name__ == "__main__":
    init_all()
