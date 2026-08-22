#!/usr/bin/env python3
"""LexHub — PostgreSQL/plpgsql sintaksis validatori (OFFLINE).

Nima uchun: migration'ni Supabase'ga yuborishdan OLDIN sintaksis xatosini
topish kerak. Bu skript HAQIQIY PostgreSQL parseridan foydalanadi
(`pglast` -> libpg_query), ya'ni "menimcha to'g'ri" emas, balki parser
tasdig'i beriladi.

MUHIM CHEKLOV: bu FAQAT sintaksis. Semantika (jadval/ustun bor-yo'qligi,
tip mosligi, RLS ta'siri) tekshirilMAYDI — buning uchun real DB kerak.

Ishlatish:
    python tool/validate_sql_syntax.py                       # barcha migration
    python tool/validate_sql_syntax.py path/to/file.sql ...   # tanlangan fayl

O'rnatish: pip install pglast
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    from pglast import parse_sql
    from pglast.parser import parse_plpgsql_json
except ImportError:  # pragma: no cover
    print("BLOCKED: `pip install pglast` bajarilmagan — tekshiruv o'tkazilmadi.")
    sys.exit(2)

ROOT = Path(__file__).resolve().parent.parent
MIGRATIONS = ROOT / "supabase" / "migrations"

# CREATE [OR REPLACE] FUNCTION ... AS $tag$ body $tag$;
FUNC_RE = re.compile(
    r"CREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION.*?AS\s+(\$[a-zA-Z_]*\$).*?\1\s*;",
    re.IGNORECASE | re.DOTALL,
)
# DO $tag$ body $tag$;
DO_RE = re.compile(r"DO\s+(\$[a-zA-Z_]*\$)(.*?)\1\s*;", re.IGNORECASE | re.DOTALL)


def check(path: Path) -> list[str]:
    """Bitta faylni tekshiradi; xato matnlari ro'yxatini qaytaradi."""
    sql = path.read_text(encoding="utf-8-sig")
    errors: list[str] = []

    # 1. Top-level SQL statement'lar.
    try:
        parse_sql(sql)
    except Exception as exc:  # pglast.parser.ParseError
        errors.append(f"SQL: {exc}")

    # 2. plpgsql funksiya tanalari (libpg_query plpgsql parseri).
    for idx, match in enumerate(FUNC_RE.finditer(sql), start=1):
        stmt = match.group(0)
        if "plpgsql" not in stmt.lower():
            continue  # LANGUAGE sql — 1-bosqichda allaqachon tekshirildi
        try:
            parse_plpgsql_json(stmt)
        except Exception as exc:
            line = sql[: match.start()].count("\n") + 1
            errors.append(f"plpgsql funksiya #{idx} (satr ~{line}): {exc}")

    # 3. Anonim DO bloklari: plpgsql parseri CREATE FUNCTION kutadi, shuning
    #    uchun tanani vaqtincha funksiyaga o'raymiz.
    for idx, match in enumerate(DO_RE.finditer(sql), start=1):
        body = match.group(2)
        wrapped = (
            "CREATE FUNCTION __syntax_probe__() RETURNS void LANGUAGE plpgsql "
            f"AS $__probe__${body}$__probe__$;"
        )
        try:
            parse_plpgsql_json(wrapped)
        except Exception as exc:
            line = sql[: match.start()].count("\n") + 1
            errors.append(f"DO bloki #{idx} (satr ~{line}): {exc}")

    return errors


def main(argv: list[str]) -> int:
    targets = [Path(a) for a in argv[1:]] or sorted(MIGRATIONS.glob("*.sql"))
    if not targets:
        print("Tekshirish uchun fayl topilmadi.")
        return 2

    failed = 0
    for path in targets:
        errors = check(path)
        if errors:
            failed += 1
            print(f"[XATO] {path.name}")
            for err in errors:
                print(f"       {err}")
        else:
            print(f"[OK]   {path.name}")

    print(f"\nJami: {len(targets)} fayl, xatolik: {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
