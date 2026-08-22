"""LexHub — live `public.questions` ustunlarini aniqlash (READ-ONLY).

Nima uchun: repo migration'lari (`supabase/migrations/*.sql`) live cloud bilan
drift qilgan (`body` faqat live'da bor). INSERT payload live'dagi BARCHA
NOT NULL ustunni qoplashi kerak, shuning uchun avval ustunlar to'plami
aniqlanadi. `information_schema` va OpenAPI root anon kalit bilan 401
qaytaradi, shuning uchun har bir nomzod ustun `select=` bilan sinaladi:
  HTTP 200 -> ustun BOR
  HTTP 400 (42703 does not exist) -> ustun YO'Q

Maxfiylik: kalitlar chop etilmaydi.
"""
import json
import urllib.error
import urllib.request

with open("env/prod.json", encoding="utf-8") as f:
    cfg = json.load(f)
URL = cfg["SUPABASE_URL"].rstrip("/")
KEY = cfg["SUPABASE_ANON_KEY"]
H = {"apikey": KEY, "Authorization": f"Bearer {KEY}", "Accept": "application/json"}

CANDIDATES = [
    "id", "user_id", "category_id", "category", "title", "body", "content",
    "description", "anonymized_question", "ai_summary", "ai_answer", "status",
    "is_anonymous", "is_resolved", "is_answered", "views_count",
    "upvotes_count", "downvotes_count", "helpful_count", "answers_count",
    "comments_count", "created_at", "updated_at", "resolved_at", "tags",
    "attachments", "language", "region", "priority", "urgency", "expert_id",
    "accepted_answer_id", "slug", "metadata", "search_vector", "embedding",
    "deleted_at", "is_deleted", "author_name", "author_avatar_url",
    "is_featured", "is_public", "visibility", "moderation_status",
    "reported_count", "last_activity_at", "location", "attachment_url",
]

# INSERT payload'da yuboriladigan kalitlar (buildQuestionInsertPayload).
SENT = {
    "user_id", "category_id", "title", "body", "description", "content",
    "anonymized_question", "is_anonymous", "status", "ai_summary",
    "views_count", "upvotes_count", "answers_count",
}


def probe(col):
    req = urllib.request.Request(
        f"{URL}/rest/v1/questions?select={col}&limit=1", headers=H
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status, ""
    except urllib.error.HTTPError as e:
        try:
            msg = json.loads(e.read().decode()).get("message", "")
        except Exception:
            msg = ""
        return e.code, msg


present, absent = [], []
for col in CANDIDATES:
    st, msg = probe(col)
    (present if st == 200 else absent).append(col)

print("=" * 78)
print("LIVE public.questions — ustunlar to'plami (anon kalit, READ-ONLY)")
print("=" * 78)
print(f"\nMAVJUD ({len(present)}):")
for c in present:
    mark = "SENT" if c in SENT else "    "
    print(f"  [{mark}] {c}")
print(f"\nYO'Q ({len(absent)}):")
print("  " + ", ".join(absent))
print("\nPayloadda bor, lekin live'da YO'Q (PGRST204 xatosi bo'lardi):")
missing = sorted(SENT - set(present))
print("  " + (", ".join(missing) if missing else "<yo'q>"))
print("\nLive'da bor, payloadda YO'Q (default yoki nullable bo'lishi shart):")
print("  " + ", ".join(c for c in present if c not in SENT))
print("\nDIQQAT: nullability anon kalit bilan aniqlanmaydi — RLS (42501)")
print("NOT NULL (23502) tekshiruvidan OLDIN ishlaydi.")
