"""HAQIQIY JWT bilan GVARD TRIGGER'INI o'lchash (CLAUDE.md §0: CLAIM != EVIDENCE).

NIMA UCHUN: `20260830020000` va `20260830030000` migratsiyalari gvard
trigger'ining KLIENT `UPDATE` ini rad etishini TEKSHIRA OLMAYDI — migratsiya
sessiyasida `session_user = postgres`, ya'ni `is_privileged_db_role()` TRUE va
gvard ataylab o'tkazib yuboradi (`SET SESSION AUTHORIZATION` esa 42501 beradi).
Yagona sodiq kanal — HAQIQIY JWT bilan PostgREST `PATCH`.

QOLDIQ MA'LUMOT: oxirida `withdraw_expert_application()` arizani O'CHIRADI.
`auth.users` qatori esa alohida migratsiya bilan tozalanadi (klient uchun
o'zini o'chirish yo'li YO'Q). Ariza `verified_at IS NULL` bo'lib turadi, ya'ni
ilovaning ekspert ro'yxatiga (u faqat tasdiqlanganlarni ko'rsatadi) TUSHMAYDI —
soxta advokat paydo bo'lmaydi.

ISHLATISH: python tool/probe_expert_guard.py
Kalitlar `env/prod.json` dan o'qiladi va HECH QACHON chop etilmaydi.
"""

import json
import sys
import urllib.error
import urllib.request
import uuid

with open("env/prod.json", encoding="utf-8") as fh:
    _cfg = json.load(fh)
BASE = _cfg["SUPABASE_URL"].rstrip("/")
ANON = _cfg["SUPABASE_ANON_KEY"]

PROBE_TAG = "guardprobe-" + uuid.uuid4().hex[:10]
EMAIL = f"{PROBE_TAG}@lexhub.invalid"
PASSWORD = uuid.uuid4().hex + "Aa1!"


def call(method, path, body=None, token=None, extra=None):
    url = f"{BASE}{path}"
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("apikey", ANON)
    req.add_header("Authorization", f"Bearer {token or ANON}")
    req.add_header("Content-Type", "application/json")
    for k, v in (extra or {}).items():
        req.add_header(k, v)
    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            raw = res.read().decode()
            return res.status, (json.loads(raw) if raw.strip() else None)
    except urllib.error.HTTPError as err:
        raw = err.read().decode()
        try:
            return err.code, json.loads(raw)
        except json.JSONDecodeError:
            return err.code, raw


results = []


def record(name, ok, detail):
    results.append((name, ok, detail))
    print(f"[{'PASS' if ok else 'FAIL'}] {name}: {detail}", flush=True)


# ---------------------------------------------------------------- 1. SIGN UP
status, body = call("POST", "/auth/v1/signup",
                    {"email": EMAIL, "password": PASSWORD,
                     "data": {"full_name": "PROBE Guard", "role": "citizen"}})
if status != 200 or not isinstance(body, dict):
    print(f"BLOCKED: signup {status} -> {body}")
    sys.exit(1)
token = body.get("access_token")
uid = (body.get("user") or {}).get("id")
if not token or not uid:
    print(f"BLOCKED: sessiya qaytmadi (mailer_autoconfirm?) {status} -> "
          f"{ {k: v for k, v in body.items() if k != 'access_token'} }")
    sys.exit(1)
record("1. signUp", True, f"uid={uid} jwt_len={len(token)}")

# ------------------------------------------------------------------ 2. APPLY
license_no = "LX-PROBE-" + uuid.uuid4().hex[:12].upper()
status, body = call("POST", "/rest/v1/rpc/apply_for_expert_verification",
                    {"p_specialization": "PROBE Fuqarolik huquqi",
                     "p_experience_years": 3,
                     "p_license_number": license_no,
                     "p_consultation_fee": 0},
                    token=token)
if status != 200 or not isinstance(body, dict) or \
        body.get("status") != "pending_verification":
    print(f"BLOCKED: apply {status} -> {body}")
    sys.exit(1)
record("2. apply (real JWT)", True,
       f"status={body.get('status')} expert_id={body.get('expert_id')}")

# --------------------------------------------------- 3. GVARD — 6 TA URINISH
# HAR BIR QIYMAT OLDINGI QIYMATDAN FARQ QILISHI SHART. Gvard
# `IS DISTINCT FROM` bilan qaraydi, ya'ni AYNI qiymat yozilsa u (to'g'ri
# ravishda) JIM o'tadi va test YOLG'ON "himoya yo'q" xulosasini berardi.
# O'LCHANGAN (2026-08-30, probe'ning 1-ishga tushishi): `rating: 5.0`
# HTTP 200 qaytardi — chunki `rating` ustunining DEFAULT qiymati AYNAN
# 5.00 (`20260819_base_schema.sql:101`). `rejected_at: null` ham 200
# qaytardi — OLD qiymati ham NULL edi. Ikkisi ham probe nuqsoni edi,
# gvard nuqsoni EMAS. (DEFAULT 5.00 ning O'ZI alohida nuqson — soxta
# reyting; u alohida hal qilinadi.)
TAMPERS = [
    ("rating", {"rating": 4.25}),
    ("reviews_count", {"reviews_count": 999}),
    ("verified_at", {"verified_at": "2026-01-01T00:00:00Z"}),
    ("user_id", {"user_id": str(uuid.uuid4())}),
    ("rejected_at", {"rejected_at": "2020-01-01T00:00:00Z"}),
    ("rejection_reason", {"rejection_reason": "o'zim yozdim"}),
]
for field, patch in TAMPERS:
    status, body = call("PATCH", f"/rest/v1/expert_profiles?user_id=eq.{uid}",
                        patch, token=token,
                        extra={"Prefer": "return=representation"})
    msg = body.get("message") if isinstance(body, dict) else body
    rejected = status >= 400
    record(f"3.{field} PATCH rad etildi", rejected,
           f"HTTP {status} | {msg}")

# ------------------------------------------------- 4. NAZORAT: ruxsat etilgan
status, body = call("PATCH", f"/rest/v1/expert_profiles?user_id=eq.{uid}",
                    {"workplace": "PROBE ofis"}, token=token,
                    extra={"Prefer": "return=representation"})
record("4. NAZORAT: `workplace` O'TDI (gvard hammani bloklamaydi)",
       status == 200, f"HTTP {status} | {body if status != 200 else 'ok'}")

# ----------------------------------------------------------- 5. TOZALASH RPC
status, body = call("POST", "/rest/v1/rpc/withdraw_expert_application",
                    {}, token=token)
withdrawn = status == 200 and isinstance(body, dict) and \
    body.get("status") == "withdrawn"
record("5. withdraw_expert_application", withdrawn, f"HTTP {status} | {body}")

status, body = call("GET", f"/rest/v1/expert_profiles?user_id=eq.{uid}"
                           "&select=user_id", token=token)
gone = status == 200 and body == []
record("6. ariza qatori YO'Q", gone, f"HTTP {status} | {body}")

print("\n=== XULOSA ===")
print(f"PROBE_EMAIL={EMAIL}")
print(f"PROBE_UID={uid}")
failed = [n for n, ok, _ in results if not ok]
print(f"jami={len(results)} pass={len(results) - len(failed)} "
      f"fail={len(failed)}")
if failed:
    print("YIQILGAN: " + ", ".join(failed))
sys.exit(1 if failed else 0)
