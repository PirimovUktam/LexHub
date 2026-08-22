"""LexHub — hardcoded UI matnlarini skanerlash (l10n migratsiyasi uchun).

Bu FAQAT ishchi vosita (audit hisobi uchun raqam beradi). Blokirovka qiluvchi
tekshiruv `test/l10n/no_hardcoded_ui_strings_test.dart` ichida.
"""
import pathlib, re, sys, json

# Windows konsoli cp1252 bo'lgani uchun emoji/kirill chiqishi crash qilmasin.
try:
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
except Exception:  # pragma: no cover
    pass

ROOT = pathlib.Path('lib')

# Foydalanuvchiga ko'rinadigan matn KUTILADIGAN nomlangan argumentlar / joylar.
UI_SLOTS = re.compile(
    r"(?:\bText\(|\bText\.rich\(|label:|labelText:|title:|subtitle:|hintText:|"
    r"tooltip:|helperText:|errorText:|semanticLabel:|message:|content:|"
    r"actionText:|prefixText:|suffixText:|counterText:)")

STR = re.compile(r"""(?<![\w$])(?:'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)")""")

# Texnik (tarjima qilinmaydigan) qiymatlar.
TECH = re.compile(r"""^(?:
      (?:dd|MM|yyyy|HH|mm|ss|[.,:/ -])+ # sana formatlari
    | \s* )$""", re.X)

# Bo'shliqsiz bitta token (identifikator/yo'l/kalit bo'lishi mumkin).
ONE_TOKEN = re.compile(r'^[\w./:@#-]+$')


def _is_technical_token(s: str) -> bool:
    """Bo'shliqsiz token texnikmi? UI yorliqlari ("Tushundim") texnik EMAS."""
    if not ONE_TOKEN.match(s):
        return False
    if re.search(r'[./:@#_]|\d', s):        # yo'l / kalit / versiya / snake_case
        return True
    if re.search(r'[a-z][A-Z]', s):         # camelCase identifikator
        return True
    # Bitta alifboli so'z: bosh harf katta bo'lsa UI yorlig'i deb hisoblanadi.
    return s[:1].islower()


def is_userfacing(v: str) -> bool:
    # `${...}` / `$ident` interpolyatsiyalarini olib tashlaymiz: "${x} ta" da
    # tarjima qilinadigan qism "ta", "${x}" esa emas.
    bare = re.sub(r'\$\{[^}]*\}|\$\w+', '', v)
    s = bare.strip()
    if len(s) < 3:
        return False
    if len(re.findall(r'[A-Za-z]', s)) < 3:
        return False
    if TECH.match(s) or _is_technical_token(s):
        return False
    if v.startswith(('package:', 'assets/', 'http://', 'https://', 'lib/')):
        return False
    return True


def scan():
    out = {}
    for f in sorted(ROOT.rglob('*.dart')):
        rel = f.as_posix()
        if '/l10n/gen/' in rel:
            continue
        hits = []
        lines = f.read_text(encoding='utf-8').split('\n')
        for i, line in enumerate(lines, 1):
            st = line.strip()
            if st.startswith(('//', '///', '*', '/*', 'import ', 'export ')):
                continue
            # Kontekst: shu qatorda yoki oldingi 2 qatorda UI slot bormi?
            ctx = '\n'.join(lines[max(0, i - 3):i])
            if not UI_SLOTS.search(ctx):
                continue
            for m in STR.finditer(line):
                v = m.group(1) if m.group(1) is not None else m.group(2)
                if is_userfacing(v):
                    hits.append((i, v))
        if hits:
            out[rel] = hits
    return out


if __name__ == '__main__':
    res = scan()
    total = sum(len(v) for v in res.values())
    if '--json' in sys.argv:
        print(json.dumps(res, ensure_ascii=False, indent=1))
        sys.exit(0)
    for rel, hits in res.items():
        print(f'--- {rel}  ({len(hits)})')
        for i, v in hits:
            print(f'   {i}: {v}')
    print(f'\nTOTAL hardcoded UI literals: {total} in {len(res)} files')
