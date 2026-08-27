"""`X.from('jadval')` -> `X.db('jadval')` mexanik ko'chirish + import qo'shish.

NIMA UCHUN SKRIPT: 36 chaqiruv joyi 8 faylda; o'zgarish bir xil va
`flutter analyze` + testlar bilan tekshiriladi. Skript FAQAT jadval nomi
STRING yoki `kXxxTable` konstantasi bo'lgan `.from(` larni almashtiradi —
`List.from(...)`, `Model.from(json)` kabi chaqiruvlarga TEGMAYDI.
"""
import re
import sys

IMPORT = "import 'package:lexhub/core/network/supabase_db.dart';"
FILES = [
    "lib/features/auth/data/datasources/auth_remote_datasource.dart",
    "lib/features/citizen_services/data/datasources/citizen_services_remote_datasource.dart",
    "lib/features/community_forum/data/datasources/community_forum_remote_datasource.dart",
    "lib/features/community_forum/presentation/pages/question_detail_page.dart",
    "lib/features/consultations/data/datasources/consultation_remote_datasource.dart",
    "lib/features/document_builder/data/datasources/document_templates_remote_datasource.dart",
    "lib/features/legal_assistant/data/datasources/legal_assistant_remote_datasource.dart",
    "lib/features/legal_experts/data/datasources/legal_experts_remote_datasource.dart",
]
PATTERN = re.compile(r"\.from\((?=['\"]|k[A-Z])")


def add_import(lines: list[str]) -> list[str]:
    if any(line.strip() == IMPORT for line in lines):
        return lines
    idx = [i for i, l in enumerate(lines) if l.startswith("import 'package:lexhub/")]
    if not idx:
        raise SystemExit("lexhub import topilmadi")
    target = next((i for i in idx if lines[i] > IMPORT), None)
    pos = target if target is not None else idx[-1] + 1
    return lines[:pos] + [IMPORT] + lines[pos:]


total = 0
for path in FILES:
    src = open(path, "rb").read().decode("utf-8")
    new, n = PATTERN.subn(".db(", src)
    if n == 0:
        raise SystemExit(f"{path}: hech narsa almashtirilmadi")
    lines = new.split("\n")
    lines = add_import(lines)
    open(path, "wb").write("\n".join(lines).encode("utf-8"))
    print(f"{path}: {n} chaqiruv")
    total += n
print(f"JAMI: {total}")
