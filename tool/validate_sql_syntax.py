#!/usr/bin/env python3
"""LexHub — PostgreSQL/plpgsql sintaksis validatori (OFFLINE).

Nima uchun: migration'ni Supabase'ga yuborishdan OLDIN sintaksis xatosini
topish kerak. Bu skript HAQIQIY PostgreSQL parseridan foydalanadi
(`pglast` -> libpg_query), ya'ni "menimcha to'g'ri" emas, balki parser
tasdig'i beriladi.

MUHIM CHEKLOV: bu FAQAT sintaksis. Semantika (jadval/ustun bor-yo'qligi,
tip mosligi, RLS ta'siri) tekshirilMAYDI — buning uchun real DB kerak.

IKKINCHI CHEKLOV (o'lchandi 2026-08-30): plpgsql parseri GAP TUZILISHINI
tekshiradi, gap ICHIDAGI SQL ifodani esa YO'Q. Isbot: `NEW.updated_at := ;`
mutatsiyasi `[OK]` bergan, `END IF;` ni olib tashlash esa `[XATO]` bergan.
Ya'ni "[OK]" = "tuzilish buzilmagan", "ifoda to'g'ri" DEGANI EMAS.

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

# `$tag$` yoki `$$`. `$1` kabi pozitsion parametr ATAYLAB moslashmaydi.
_DOLLAR_TAG = re.compile(r"\$(?:[A-Za-z_][A-Za-z_0-9]*)?\$")


def _blank_comments(sql: str) -> str:
    """`--` izohlarni BO'SH JOY bilan almashtiradi (satr raqami va indekslar
    O'ZGARMAYDI, ya'ni xato joyi hamon haqiqiy faylga to'g'ri keladi).

    NIMA UCHUN KERAK: `FUNC_RE`/`DO_RE` xom matnga qo'llanganda izoh ichidagi
    `CREATE OR REPLACE FUNCTION` so'zi ham moslikni BOSHLAB yuboradi va
    non-greedy `.*?` keyingi haqiqiy `$tag$ ... $tag$;` gacha cho'ziladi.
    Natijada parserga IKKI funksiya bir gap bo'lib beriladi -> "syntax error at
    or near CREATE" (soxta xato), haqiqiy tana esa TEKSHIRILMAY qoladi.
    O'lchangan 2026-08-30:
    `20260829130000_expert_moderation_guard_fix_and_apply_cooldown.sql` da
    moslik #1 satr 13 (IZOH) dan 123 gacha cho'zilgan.

    Skaner satr literal (`'...'`) va dollar-quoted tanani hisobga oladi:
    izoh belgisi satr ichida bo'lsa TEGILMAYDI, tana ichidagi izoh esa
    plpgsql uchun ham haqiqiy izoh, shuning uchun bo'shatiladi.
    """
    out = list(sql)
    n = len(sql)
    i = 0
    in_str = False
    tag: str | None = None
    while i < n:
        ch = sql[i]
        if in_str:
            # `''` — ikki marta ketma-ket: birinchisi yopadi, ikkinchisi ochadi.
            if ch == "'":
                in_str = False
            i += 1
            continue
        if tag is not None and sql.startswith(tag, i):
            i += len(tag)
            tag = None
            continue
        if ch == "-" and sql.startswith("--", i):
            end = sql.find("\n", i)
            end = n if end < 0 else end
            for k in range(i, end):
                out[k] = " "
            i = end
            continue
        if ch == "'":
            in_str = True
            i += 1
            continue
        if ch == "$" and tag is None:
            m = _DOLLAR_TAG.match(sql, i)
            if m:
                tag = m.group(0)
                i = m.end()
                continue
        i += 1
    return "".join(out)


def check(path: Path) -> list[str]:
    """Bitta faylni tekshiradi; xato matnlari ro'yxatini qaytaradi."""
    raw = path.read_text(encoding="utf-8-sig")
    # Funksiya/DO chegarasini topish uchun izohsiz nusxa (indekslar bir xil).
    sql = _blank_comments(raw)
    errors: list[str] = []

    # 1. Top-level SQL statement'lar (XOM matn — izoh SQL uchun qonuniy).
    try:
        parse_sql(raw)
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
