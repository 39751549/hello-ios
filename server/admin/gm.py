# -*- coding: utf-8 -*-
"""GM 后台:web 界面 + 操作 API"""
import os
from datetime import datetime
from fastapi import APIRouter, Request, Depends, HTTPException, Form, responses
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from database import get_db
import models
import schemas
from security import hash_password, verify_password, create_access_token, decode_token
from config import GM_DEFAULT_USER, GM_DEFAULT_PASSWORD
from utils import add_player_item
from routers.player import build_player_info
import game_logic

router = APIRouter(prefix="/admin", tags=["gm"])
TEMPLATES = Jinja2Templates(directory=os.path.join(os.path.dirname(__file__), "templates"))


def get_gm(request: Request, db: Session = Depends(get_db)):
    token = request.cookies.get("gm_token", "")
    try:
        payload = decode_token(token)
        gid = payload.get("gid")
    except Exception:
        return None
    if not gid:
        return None
    return db.query(models.GmUser).filter_by(id=gid).first()


def require_gm(request: Request, db: Session = Depends(get_db)):
    gm = get_gm(request, db)
    if not gm:
        raise HTTPException(401, "未登录")
    return gm


def log_gm(db: Session, gm_user: str, action: str, target: str = "", detail: str = ""):
    db.add(models.GmLog(gm_user=gm_user, action=action, target=target, detail=detail))
    db.commit()


# ============ 页面 ============
@router.get("/")
def index(request: Request, db: Session = Depends(get_db)):
    if get_gm(request, db):
        return responses.RedirectResponse("/admin/dashboard", status_code=302)
    return responses.RedirectResponse("/admin/login", status_code=302)


@router.get("/login")
def login_page(request: Request):
    return TEMPLATES.TemplateResponse("login.html", {"request": request, "error": ""})


@router.post("/login")
def login_do(request: Request, username: str = Form(...), password: str = Form(...), db: Session = Depends(get_db)):
    gm = db.query(models.GmUser).filter_by(username=username.strip()).first()
    if not gm or not verify_password(password, gm.password_hash):
        return TEMPLATES.TemplateResponse("login.html", {"request": request, "error": "用户名或密码错误"})
    token = create_access_token({"gid": gm.id})
    resp = responses.RedirectResponse("/admin/dashboard", status_code=302)
    resp.set_cookie("gm_token", token, httponly=True, max_age=7 * 86400)
    return resp


@router.get("/logout")
def logout():
    resp = responses.RedirectResponse("/admin/login", status_code=302)
    resp.delete_cookie("gm_token")
    return resp


@router.get("/dashboard")
def dashboard(request: Request, q: str = "", db: Session = Depends(get_db)):
    gm = require_gm(request, db)
    query = db.query(models.Player, models.User).join(models.User, models.Player.user_id == models.User.id)
    if q:
        query = query.filter(
            (models.Player.nickname.contains(q)) | (models.User.username.contains(q))
        )
    rows = query.order_by(models.Player.id.desc()).limit(200).all()
    players = []
    for p, u in rows:
        players.append({
            "id": p.id, "username": u.username, "nickname": p.nickname,
            "level": p.level, "gold": p.gold, "diamond": p.diamond,
            "vip": p.vip, "kill_count": p.kill_count, "boss_kill_count": p.boss_kill_count,
            "created_at": p.created_at.strftime("%Y-%m-%d %H:%M") if p.created_at else "",
        })
    total = db.query(models.Player).count()
    total_gold = sum(p.gold for p, _ in rows)
    total_diamond = sum(p.diamond for p, _ in rows)
    return TEMPLATES.TemplateResponse("dashboard.html", {
        "request": request, "gm": gm.username, "players": players, "q": q,
        "total": total, "total_gold": total_gold, "total_diamond": total_diamond,
    })


@router.get("/player/{pid}")
def player_detail(pid: int, request: Request, db: Session = Depends(get_db)):
    gm = require_gm(request, db)
    p = db.query(models.Player).filter_by(id=pid).first()
    if not p:
        raise HTTPException(404, "玩家不存在")
    u = db.query(models.User).filter_by(id=p.user_id).first()
    info = build_player_info(db, p)
    items = db.query(models.Item).order_by(models.Item.type, models.Item.id).all()
    recharges = db.query(models.RechargeRecord).filter_by(player_id=pid).order_by(
        models.RechargeRecord.id.desc()).limit(20).all()
    return TEMPLATES.TemplateResponse("player.html", {
        "request": request, "gm": gm.username, "p": p, "u": u, "info": info,
        "all_items": items, "recharges": recharges,
        "type_name": game_logic.TYPE_NAME, "rarity_name": game_logic.RARITY_NAME,
    })


# ============ 操作 API(返回 JSON) ============
@router.post("/api/recharge")
def api_recharge(req: schemas.GmRechargeIn, request: Request, db: Session = Depends(get_db)):
    gm = require_gm(request, db)
    p = db.query(models.Player).filter_by(id=req.player_id).first()
    if not p:
        raise HTTPException(404, "玩家不存在")
    p.diamond += req.diamond
    db.add(models.RechargeRecord(
        player_id=p.id, diamond=req.diamond, amount_yuan=req.amount_yuan,
        gm_user=gm.username, remark=req.remark,
    ))
    log_gm(db, gm.username, "recharge", f"player:{p.id}", f"+{req.diamond}钻石")
    db.commit()
    return schemas.ApiResult(msg=f"已充值 {req.diamond} 钻石给 {p.nickname}")


@router.post("/api/give_item")
def api_give_item(req: schemas.GmGiveItemIn, request: Request, db: Session = Depends(get_db)):
    gm = require_gm(request, db)
    p = db.query(models.Player).filter_by(id=req.player_id).first()
    item = db.query(models.Item).filter_by(id=req.item_id).first()
    if not p or not item:
        raise HTTPException(404, "玩家或物品不存在")
    add_player_item(db, p.id, item.id, req.count)
    log_gm(db, gm.username, "give_item", f"player:{p.id}", f"{item.name}x{req.count}")
    db.commit()
    return schemas.ApiResult(msg=f"已发放 {item.name} x{req.count} 给 {p.nickname}")


@router.post("/api/set_level")
def api_set_level(req: schemas.GmSetLevelIn, request: Request, db: Session = Depends(get_db)):
    gm = require_gm(request, db)
    p = db.query(models.Player).filter_by(id=req.player_id).first()
    if not p:
        raise HTTPException(404, "玩家不存在")
    if req.level < 1 or req.level > 120:
        raise HTTPException(400, "等级范围 1-120")
    old = p.level
    p.level = req.level
    # 同步基础属性:每级 hp+20 atk+3 df+2,从1级重算
    p.hp = 200 + (req.level - 1) * 20
    p.atk = 20 + (req.level - 1) * 3
    p.df = 10 + (req.level - 1) * 2
    p.cur_hp = p.hp
    log_gm(db, gm.username, "set_level", f"player:{p.id}", f"{old}->{req.level}")
    db.commit()
    return schemas.ApiResult(msg=f"{p.nickname} 等级设为 {req.level}")


@router.post("/api/set_currency")
def api_set_currency(req: schemas.GmSetCurrencyIn, request: Request, db: Session = Depends(get_db)):
    gm = require_gm(request, db)
    p = db.query(models.Player).filter_by(id=req.player_id).first()
    if not p:
        raise HTTPException(404, "玩家不存在")
    detail = []
    if req.gold is not None:
        detail.append(f"gold:{p.gold}->{req.gold}")
        p.gold = req.gold
    if req.diamond is not None:
        detail.append(f"diamond:{p.diamond}->{req.diamond}")
        p.diamond = req.diamond
    log_gm(db, gm.username, "set_currency", f"player:{p.id}", ",".join(detail))
    db.commit()
    return schemas.ApiResult(msg=f"{p.nickname} 货币已更新")


@router.get("/api/logs")
def api_logs(request: Request, db: Session = Depends(get_db)):
    require_gm(request, db)
    logs = db.query(models.GmLog).order_by(models.GmLog.id.desc()).limit(100).all()
    return schemas.ApiResult(data=[{
        "id": l.id, "gm_user": l.gm_user, "action": l.action,
        "target": l.target, "detail": l.detail,
        "time": l.created_at.strftime("%Y-%m-%d %H:%M:%S") if l.created_at else "",
    } for l in logs])
