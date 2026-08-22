"""LexHub — `questions_user_id_fkey` FK va `public.profiles` holatini live tekshirish.

READ-ONLY. Hech qanday INSERT/UPDATE/DELETE yo'q. Maxfiylik: kalitlar va host
chop etilmaydi, UUID'lar redacted ko'rsatiladi.

Texnika: anon kalit bilan `information_schema` 401 qaytaradi, shuning uchun FK
PostgREST embedding orqali aniqlanadi:
  `select=id,profiles!questions_user_id_fkey(id)`
  HTTP 200  -> FK AYNAN shu nom bilan mavjud va `profiles`ga ishora qiladi
  HTTP 400 (PGRST200) -> bunday FK yo'q

Foydalanish:  python tool/live_fk_profiles_probe.py
"""
import json
import urllib.error
import urllib.request

with open("env/prod.json", encoding="utf-8") as f:
    cfg = json.load(f)
URL = cfg["SUPABASE_URL"].rstrip("/")
KEY = cfg["SUPABASE_ANON_KEY"]
H = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Accept": "application/json"}


def get(path, extra=None):
    req = urllib.request.Request(f"{URL}/rest/v1/{path}", headers={**H, **(extra or {})})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, r.read().decode(), dict(r.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(), dict(e.headers)


def msg(raw, n=110):
    try:
        d = json.loads(raw)
        out = "; ".join(str(d.get(k, "")) for k in ("code", "message", "details") if d.get(k))
    except Exception:
        out = raw
    out = out.replace("\n", " ")
    return out if len(out) <= n else out[: n - 1] + "…"


def redact(u):
    """UUID'ni redacted ko'rsatish: 8 ta bosh belgi + oxirgi 4."""
    if not u or len(str(u)) < 16:
        return "<yo'q>"
    s = str(u)
    return f"{s[:8]}…{s[-4:]}"


print("=" * 78)
print("LIVE PROBE — questions_user_id_fkey + public.profiles   (READ-ONLY)")
print("=" * 78)

print("\n[1] FK ta'rifi — PostgREST embedding orqali (constraint nomi bilan)")
for label, sel in (
    ("questions -> profiles (fkey nomi bilan)", "id,profiles!questions_user_id_fkey(id)"),
    ("questions -> profiles (nomsiz)", "id,profiles(id)"),
    ("questions -> categories (task-1)", "id,categories(id,name)"),
    ("questions -> question_categories", "id,question_categories(id)"),
):
    st, body, _ = get(f"questions?select={sel}&limit=1")
    verdict = "FK BOR" if st == 200 else "FK YO'Q / xato"
    print(f"    {label:42} -> HTTP {st}  {verdict}")
    if st != 200:
        print(f"        {msg(body)}")

print("\n[2] public.profiles — o'qish va sanoq")
st, body, hh = get("profiles?select=id&limit=1", {"Prefer": "count=exact"})
print(f"    GET profiles           -> HTTP {st}  Content-Range={hh.get('Content-Range')}")
if st != 200:
    print(f"        {msg(body)}")

st2, body2, _ = get("profiles?select=id,full_name,role,created_at&order=created_at.desc&limit=5")
print(f"    GET profiles (last 5)  -> HTTP {st2}")
if st2 == 200:
    rows = json.loads(body2)
    if not rows:
        print("        (0 qator — profiles BO'SH yoki RLS ko'rsatmadi)")
    for r in rows:
        print(
            f"        id={redact(r.get('id'))}  role={r.get('role')}  "
            f"full_name={'<bor>' if r.get('full_name') else '<NULL>'}  "
            f"created_at={r.get('created_at')}"
        )
else:
    print(f"        {msg(body2)}")

print("\n[3] profiles ustunlari (200 = bor, 400 = yo'q)")
for col in (
    "id", "full_name", "avatar_url", "phone", "role", "reputation_points",
    "is_verified", "email", "username", "created_at", "updated_at",
    "language", "region", "is_anonymous_mode",
):
    st, body, _ = get(f"profiles?select={col}&limit=1")
    note = "" if st == 200 else "  " + msg(body, 70)
    print(f"    {col:20} -> HTTP {st}{note}")

print("\n[4] questions.user_id ustuni va joriy qatorlar")
st, body, hh = get("questions?select=id,user_id&limit=3", {"Prefer": "count=exact"})
print(f"    GET questions.user_id  -> HTTP {st}  Content-Range={hh.get('Content-Range')}")
if st == 200:
    for r in json.loads(body):
        print(f"        user_id={redact(r.get('user_id'))}")
else:
    print(f"        {msg(body)}")

print("\n[5] boshqa jadvallarning profiles FK'lari (drift solishtirish)")
for tbl, sel in (
    ("answers", "id,profiles(id)"),
    ("votes", "id,profiles(id)"),
    ("expert_profiles", "id,profiles(id)"),
):
    st, body, _ = get(f"{tbl}?select={sel}&limit=1")
    print(f"    {tbl:16} -> HTTP {st}  {'FK BOR' if st == 200 else msg(body, 70)}")

print("\n[6] auth.users bilan bog'liqlik (PostgREST auth schema'ni ko'rsatmaydi)")
st, body, _ = get("questions?select=id,users(id)&limit=1")
print(f"    questions -> users     -> HTTP {st}  {msg(body, 90) if st != 200 else 'BOR'}")

print("\nDONE — hech qanday yozuv amalga oshirilmadi.")
