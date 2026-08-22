"""LexHub — live `public.questions.body` holatini o'qish (READ-ONLY).

Maxfiylik: SUPABASE_URL / SUPABASE_ANON_KEY faqat process ichida ishlatiladi,
hech qachon chop etilmaydi (host maskalanadi).

Foydalanish:  python tool/live_body_probe.py
"""
import json
import sys
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


def short(v, n=60):
    if v is None:
        return "NULL"
    s = str(v).replace("\n", " ")
    return s if len(s) <= n else s[: n - 1] + "…"


print("=" * 78)
print("LIVE PROBE — public.questions.body  (READ-ONLY, host masked)")
print("=" * 78)

# 1) Oxirgi 3 savol: user SQL join ekvivalenti
st, bodytxt, _ = get(
    "questions?select=id,category_id,title,body,description,content,"
    "anonymized_question,created_at&order=created_at.desc&limit=3"
)
print(f"\n[1] GET questions (last 3) -> HTTP {st}")
cats = {}
stc, catstxt, _ = get("categories?select=id,name")
if stc == 200:
    cats = {c["id"]: c["name"] for c in json.loads(catstxt)}
print(f"    GET categories -> HTTP {stc}, {len(cats)} qator")

if st == 200:
    rows = json.loads(bodytxt)
    if not rows:
        print("    (jadval bo'sh yoki RLS ko'rsatmadi)")
    for r in rows:
        cid = r.get("category_id")
        print("    ---")
        print(f"    id            = {r.get('id')}")
        print(f"    category_id   = {cid}")
        print(f"    category_name = {cats.get(cid, '<katalogda yo`q>')}")
        print(f"    title         = {short(r.get('title'))}")
        print(f"    body          = {short(r.get('body'))}")
        print(f"    description   = {short(r.get('description'))}")
        print(f"    content       = {short(r.get('content'))}")
        print(f"    anon_question = {short(r.get('anonymized_question'))}")
        print(f"    created_at    = {r.get('created_at')}")
else:
    print("    " + short(bodytxt, 300))

# 2) body IS NULL / IS NOT NULL sanoq
for label, flt in (("body=is.null", "body=is.null"), ("body=not.is.null", "body=not.is.null"), ("hammasi", "")):
    q = "questions?select=id" + (f"&{flt}" if flt else "")
    s, _b, hh = get(q + "&limit=1", {"Prefer": "count=exact"})
    print(f"\n[2] count {label:18} -> HTTP {s}  Content-Range={hh.get('Content-Range')}")

# 3) Ustunlarning mavjudligi (200 = bor, 400 = yo'q)
print("\n[3] ustun mavjudligi (questions):")
for col in ("body", "description", "content", "anonymized_question", "title", "status"):
    s, b, _ = get(f"questions?select={col}&limit=1")
    note = "" if s == 200 else "  " + short(json.loads(b).get("message", b), 80)
    print(f"    {col:22} -> HTTP {s}{note}")

print("\n[4] public_questions_view ustunlari:")
for col in ("body", "description", "anonymized_question"):
    s, b, _ = get(f"public_questions_view?select={col}&limit=1")
    note = "" if s == 200 else "  " + short(json.loads(b).get("message", b), 80)
    print(f"    {col:22} -> HTTP {s}{note}")

print("\nDONE (hech qanday yozuv amalga oshirilmadi)")
sys.exit(0)
