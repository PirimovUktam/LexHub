"""LexHub — literal -> `l10n.*` almashtirishning umumiy vositasi.

Kirish: JSON xarita
  { "<dart fayl yo'li>": { "imports": [...], "l10nAnchor": "...",
                            "pairs": [["<xom literal>", "<dart ifoda>"], ...] } }

`pairs` ichidagi literal QUOTE'SIZ yoziladi; skript uni ' va " variantlarida
qidiradi. Har bir literal FAQAT BIR MARTA (birinchi uchrashi) almashtiriladi va
topilmasa skript XATO bilan to'xtaydi — jimgina o'tkazib yuborilmaydi.

`const` bilan bog'liq xatolar QO'LDA tuzatiladi: bu skript hech qanday
`const`ni o'zi olib tashlamaydi (noto'g'ri joydan olib tashlash xavfi bor).
"""
import json
import pathlib
import re
import sys

L10N_IMPORT = "import 'package:lexhub/core/localization/l10n.dart';"


def _insert_imports(src: str, imports: list[str]) -> str:
    lines = src.split('\n')
    idx = [i for i, l in enumerate(lines) if l.startswith('import ')]
    if not idx:
        raise SystemExit('import bloki topilmadi')
    block = lines[idx[0]:idx[-1] + 1]
    for imp in imports:
        if imp in src:
            continue
        block.append(imp)
    block.sort()
    return '\n'.join(lines[:idx[0]] + block + lines[idx[-1] + 1:])


def apply_file(path: str, spec: dict) -> int:
    p = pathlib.Path(path)
    src = p.read_text(encoding='utf-8')
    imports = spec.get('imports') or [L10N_IMPORT]
    src = _insert_imports(src, imports)

    anchor = spec.get('l10nAnchor')
    if anchor:
        if anchor not in src:
            raise SystemExit(f'{path}: l10nAnchor topilmadi: {anchor!r}')
        src = src.replace(anchor, anchor + '\n    final l10n = context.l10n;', 1)

    # `raw`: aniq manba matni almashtirishlari (const olib tashlash kabi
    # holatlar uchun). Har biri BIR MARTA va topilmasa XATO.
    for old, new in spec.get('raw', []):
        if old not in src:
            raise SystemExit(f'{path}: raw topilmadi: {old[:90]!r}')
        src = src.replace(old, new, 1)

    # `regex`: [pattern, replacement, kutilgan_son] — son mos kelmasa XATO.
    for pattern, repl, count in spec.get('regex', []):
        src, done = re.subn(pattern, repl, src)
        if done != count:
            raise SystemExit(
                f'{path}: regex {pattern!r} -> {done} marta (kutilgan {count})')

    # `constText`: `const Text("literal", style: TextStyle(...))` naqshini
    # `Text(<ifoda>, style: const TextStyle(...))` ga aylantiradi.
    # Faqat literaldan OLDINGI eng yaqin `const ` olib tashlanadi, shuning
    # uchun boshqa `const`lar tegilmaydi.
    for raw in spec.get('constText', []):
        pos = -1
        for q in ('"', "'"):
            pos = src.find(q + raw + q)
            if pos != -1:
                break
        if pos == -1:
            raise SystemExit(f'{path}: constText literal topilmadi: {raw[:70]!r}')
        cpos = src.rfind('const ', max(0, pos - 400), pos)
        if cpos == -1:
            raise SystemExit(f'{path}: constText uchun `const ` topilmadi: {raw[:70]!r}')
        src = src[:cpos] + src[cpos + 6:]
        pos -= 6
        tail_end = src.find('),', pos)
        tail = src[pos:tail_end if tail_end != -1 else pos]
        if 'style: TextStyle(' in tail:
            src = (src[:pos]
                   + tail.replace('style: TextStyle(', 'style: const TextStyle(', 1)
                   + src[pos + len(tail):])

    n = 0
    for raw, expr in spec['pairs']:
        for q in ('"', "'"):
            needle = q + raw + q
            if needle in src:
                src = src.replace(needle, expr, 1)
                n += 1
                break
        else:
            raise SystemExit(f'{path}: literal topilmadi: {raw[:80]!r}')

    for drop in spec.get('dropLines', []):
        if drop not in src:
            raise SystemExit(f'{path}: dropLines topilmadi: {drop!r}')
        src = src.replace(drop, '', 1)

    p.write_text(src, encoding='utf-8')
    return n


def main() -> None:
    mapping = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
    total = 0
    for path, spec in mapping.items():
        c = apply_file(path, spec)
        total += c
        print(f'OK  {path}  ({c})')
    print(f'TOTAL replaced: {total}')


if __name__ == '__main__':
    main()
