#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""测试 MySQL 连接,尝试不同用户名。"""
import pymysql

HOST = "180.184.41.230"
PORT = 3306
DB = "youxi"
PWD = "7ttLpWwGS5pHh65L"

for user in ["root", "youxi", "admin"]:
    try:
        conn = pymysql.connect(host=HOST, port=PORT, user=user, password=PWD,
                               database=DB, connect_timeout=8, charset="utf8mb4")
        cur = conn.cursor()
        cur.execute("SELECT VERSION()")
        ver = cur.fetchone()
        cur.execute("SHOW TABLES")
        tables = cur.fetchall()
        print(f"[OK] 用户={user}  MySQL版本={ver[0]}  现有表数={len(tables)}")
        if tables:
            print("   现有表:", [t[0] for t in tables[:20]])
        conn.close()
        print(f"\n>>> 推荐用用户名: {user}")
        break
    except Exception as e:
        print(f"[FAIL] 用户={user}  -> {e}")
