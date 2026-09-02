#!/usr/bin/env python3
"""LexHub — migration SQL uchun MEXANIK sanoq (evristika, parser EMAS).

Nima uchun `validate_sql_syntax.py` YETMAYDI: u haqiqiy PostgreSQL parseri,
ya'ni SINTAKTIK to'g'ri, lekin MA'NOSI buzilgan faylni [OK] deb o'tkazadi.
O'lchangan misol (2026-08-30): `COMMENT ON TABLE ... IS '... BERMAYDI; agar
...'` — satr literali ICHIDAGI `;` gap sonini 31 dan 32 ga o'zgartirdi;
parser uchun bu mutlaqo qonuniy, odam uchun esa "bitta izoh" ikkiga bo'lindi.
Shu sababli bu skript SONLARNI chiqaradi va ular O'ZGARSA ko'zga tashlanadi.

CHEKLOVLAR (ataylab oddiy, "yashil = to'g'ri" DEGANI EMAS):
  * `\\$(\\w+)\\$` — ya'ni `$$` (nomsiz tag) MOSLASHMAYDI;
  * faqat BUTUN satr izohi tashlanadi, satr oxiridagi `-- ...` qoladi;
  * qavs/qo'shtirnoq sanog'i dollar-blok ichidagi matnni hisobga olmaydi.

Ishlatish:
    python tool/sql_quote_check.py supabase/migrations/<fayl>.sql
"""

import re
import sys

path = sys.argv[1]
s = open(path, encoding='utf-8').read()

# 1. dollar-quoted bloklarni topish va olib tashlash
tags = re.findall(r'\$(\w+)\$', s)
print('dollar tags:', tags)
s2 = re.sub(r'\$(\w+)\$.*?\$\1\$', 'DOLLARBLOCK', s, flags=re.S)
print('dollar blocks collapsed:', s2.count('DOLLARBLOCK'))

# 2. izohlarni olib tashlash (satr boshidagi -- va satr oxiridagi -- emas:
#    faqat butun satr izoh bo'lsa)
lines = s2.split('\n')
body = '\n'.join(l for l in lines if not l.lstrip().startswith('--'))

q = body.count("'")
print("single quotes outside dollar blocks:", q, 'EVEN' if q % 2 == 0 else 'ODD -> BALANSSIZ')

print('BEGIN;', s.count('BEGIN;'), ' COMMIT;', s.count('COMMIT;'))
print('open parens', body.count('('), 'close parens', body.count(')'))

# 3. har bir statement (top-level ;) ni sanash
stmts = [x.strip() for x in body.split(';') if x.strip()]
print('statements:', len(stmts))
for i, st in enumerate(stmts):
    head = ' '.join(st.split())[:70]
    print(f'  {i+1}. {head}')
