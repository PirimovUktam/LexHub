---
name: lexhub-token-budget
description: Token sarfini maksimal tejash — lekin ish SIFATINI pasaytirmasdan. Katta ish boshlanishida, screenshot/rasm o'qish, katta fayl yoki uzun buyruq chiqishini kontekstga tortish, bir faylni qayta-qayta o'qish yoki uzun hisobot yozish oldidan ishlatiladi. Shu loyihaning transcript'idan O'LCHANGAN sarf profiliga asoslangan: qaysi harakat qancha turadi va uning arzon alternativi nima. "Tejash uchun tekshiruvni tashlab ketish" TAQIQLANGAN — tejash faqat QANDAY qarashdan keladi.
---

# LexHub — token budjeti (o'lchangan, taxmin emas)

## 0. Bir jumlada

Tejash **nimani tekshirishni kamaytirishdan** emas, **qanday qarashni
o'zgartirishdan** keladi. Isbotni tashlab ketish token tejamaydi — u CLAUDE.md
ning CLAIM ≠ EVIDENCE qoidasini buzadi va soxta success ishlab chiqaradi.

## 1. Shu loyihada O'LCHANGAN sarf profili

Manba: `~/.claude/projects/D--projects-LexHub/*.jsonl` — 4 fayl, 13 327 yozuv,
1 645 request, 30 compaction.

| Tool | tool_result hajmi | chaqiriq | o'rtacha |
|---|---|---|---|
| Read | 9 361K char (87.4%) | 370 | 25 300 char (~6.3K token) |
| Bash | 1 157K char (10.8%) | 854 | 1 355 char |
| Grep | 93K char (0.9%) | 48 | 1 930 char |
| Edit | 82K char (0.8%) | 445 | 183 char |
| Write | 14K char (0.1%) | 90 | 159 char |

Ikki hal qiluvchi fakt:

1. **19 ta PNG screenshot = barcha Read hajmining 78%.** Bitta screenshot
   436K–681K char = **~109K–170K token**. Bitta 300 qatorli Dart fayli
   ~1.5K token. Ya'ni **1 screenshot ≈ 40 ta source fayl**.
2. **74 fayl bir martadan ko'p o'qilgan; ortiqcha hajm 1 171K char
   (~293K token).** `community_forum_remote_datasource.dart` — **27 marta**,
   `payment_checkout_page.dart` — 11 marta.

Bu sessiyada `cache_read` = 0 edi, ya'ni kontekstdagi har bir bayt keyingi HAR
BIR request'da qaytadan yuboriladi. Segment boshida o'qilgan screenshot narxi
= hajmi × qolgan request soni.

Nazorat ostida BO'LMAGAN qism: SessionStart / UserPromptSubmit / Stop
hook'lari (`~/.claude/settings.json` → `.orca/agent-hooks`) conhost terminal
escape shovqinini chiqaradi. Buni tuzatmaymiz; amaliy xulosa — **kam sonli,
katta turn** shovqinni kamaytiradi.

## 2. Qat'iy qoidalar (o'lchangan foyda tartibida)

### R1 — Rasm: oxirgi chora

Screenshot o'qishdan OLDIN matnli probe'ni sina: `preview_inspect`
(rang/o'lcham/shrift uchun screenshot'dan ANIQROQ), `preview_snapshot` (matn,
rol, struktura), `adb logcat`, `adb shell dumpsys`, test assertion,
`flutter analyze`.

Rasm haqiqatan kerak bo'lsa — avval KESIB va KICHRAYTIRIB JPEG qil:

```bash
python -c "from PIL import Image; im=Image.open('s.png'); im.crop((0,240,1080,920)).resize((540,340), Image.LANCZOS).save('s_min.jpg', quality=60)"
```

O'lchangan (sintetik 1080×2400 UI screenshot): PNG 50 213 bayt → yarim
o'lchamli JPEG 28 756 bayt → kesilgan JPEG 9 238 bayt = **5.4× arzon**.
Haqiqiy screenshot'lar bu sessiyada 300–500KB edi — foyda kattaroq.
Muhitda `PIL` 12.2.0 MAVJUD, `magick` va `ffmpeg` YO'Q.

Rasmni **bir marta** o'qi va o'sha bitta o'qishda kerak bo'ladigan BARCHA
faktni yozib ol. Ikkinchi marta o'qish = to'liq narx yana bir bor.

### R2 — Bir faylni ikki marta o'qima

Har bir muhim topilma darhol **ledger**ga yoziladi: bir qator
`path:line → fakt` ko'rinishida. Ledger — `.claude/notes/<task>.md` yoki
memory fayli. Compaction'dan keyin **ledger** o'qiladi, fayl QAYTA emas.

`Edit`dan keyin natijani tekshirish uchun faylni o'qish SHART EMAS — Edit
mos kelmasa o'zi xato qaytaradi.

### R3 — Maqsad bilan o'qi

`Glob`/`Grep` bilan aniq joyni top → `Read`ni `offset`/`limit` bilan chaqir.
Bu sessiyada 370 Read'dan faqat 142 tasida `limit` bor edi.
To'liq fayl o'qish faqat ikki holatda: fayl <300 qator, YOKI uni asosan
qayta yozasan.

### R4 — Katta chiqishni Bash ICHIDA yig'

Xom log / test chiqishi / JSON'ni kontekstga tortma. Bash ichida `grep -c`,
`tail -5`, `wc -l`, `python` bilan agregat qil va FAQAT natijani chiqar:
`flutter test --reporter compact | tail -3`.

Bash o'rtachasi 1 355 char, Read o'rtachasi 25 300 char — 18× farq shundan.
`.jsonl`, `.log`, `build/` chiqishi, `pubspec.lock`, APK skan natijasi —
HECH QACHON `Read` bilan emas.
### R5 — Batching

Bir-biriga bog'liq bo'lmagan probe'larni BITTA Bash chaqiruviga birlashtir
(`echo "=== nom ==="` bilan bo'limlab). Bog'liq bo'lmagan tool'larni bitta
javobda parallel chaqir. 854 Bash chaqiruvining ko'pi 3–4 tasi bittaga
sig'ardi — har bir chaqiruv o'z overhead'ini olib keladi.

### R6 — Isbotlanganini qayta isbotlama

Shu sessiyada allaqachon olingan evidence (live `42501` natijasi, APK SHA256,
jadval qator soni) qayta ishlab chiqilmaydi — ledger'dan keltiriladi.

### R7 — Javob uzunligi

Output tokeni input'dan ~5× qimmat. So'ralmagan jadval, takroriy xulosa,
"hozir nima qilmoqchiman" bayoni va bajarilgan ishni ikkinchi marta sanab
o'tish yozilmaydi. Faktni bir marta ayt.

## 3. TEJASH TAQIQLANGAN joylar (sifat qo'riqchisi)

Quyidagilarni token uchun qisqartirish = xato ishlab chiqarish:

1. CLAUDE.md ning 5 VERIFIED sharti. Real environment, real runtime, kutilgan
   natija, negative/security stsenariy, takrorlanadigan evidence — hech qachon
   "qimmat" degan sabab bilan tashlanmaydi.
2. Fayl mazmunini o'qimasdan u haqida da'vo qilish. Qimmat bo'lsa `Grep`
   bilan aniq qatorni ol — lekin TAXMIN qilma.
3. Paket API imzosini eslab qolishga tayanish. `pubspec.lock`dagi versiya
   bo'yicha `.pub-cache`dagi manbadan aniq qatorni o'qi (`limit` bilan arzon).
4. Matn/ARB o'zgarishidan keyin `flutter analyze` va `flutter test test/l10n`.
5. Xavfsizlik testining negative qismi (anon → 401/403, begona user → 0 qator).
6. Hisobotdan ma'lum risk yoki BLOCKED bandni olib tashlash.
7. Isbot yo'q joyda "ishlaydi" deb yozish. To'g'ri javob — **BLOCKED**,
   qisqartirilgan da'vo emas.

Formula: **tejash = kamroq BAYT, kamroq TEKSHIRUV emas.**

## 4. Qimmat → arzon almashtirish jadvali

| Qimmat harakat | O'lchangan narx | Arzon alternativ |
|---|---|---|
| To'liq screenshot `Read` | 110–170K token | `preview_inspect` / `preview_snapshot` / kesilgan JPEG (~3K) |
| `.jsonl` yoki log `Read` | 100K+ | `python`/`grep -c` agregati (<1K) |
| `flutter test` to'liq chiqishi | 25K+ | `--reporter compact` + `tail -3` |
| 2000 qatorli fayl to'liq | ~25K | `Grep -n` + `Read offset/limit` (~1K) |
| Faylni 27 marta `Read` | 159K | ledger'dagi bir qator (~20 token) |
| 4 ta alohida Bash probe | 4× overhead | 1 Bash, `echo` bilan bo'limlangan |
| `find .` / `ls -R` daraxti | 10K+ | `Glob` aniq pattern bilan |
## 5. Qimmat chaqiruvdan oldin 3 savol

1. Bu ma'lumot menda ALLAQACHON bormi (ledger, oldingi natija, diff)?
2. Xuddi shu faktni matn bilan (`Grep` / `inspect` / agregat) olish mumkinmi?
3. Natijaning MENGA kerak bo'lgan qismi qancha — hammasi kerakmi yoki 5 qatori?

Uchtasidan biri "ha" bo'lsa — qimmat chaqiruvni QILMA.

## 6. Sarfni qayta o'lchash

```bash
cd "$HOME/.claude/projects/D--projects-LexHub" && PYTHONIOENCODING=utf-8 python -c "
import json,glob,collections
use={};agg=collections.Counter();cnt=collections.Counter()
for f in glob.glob('*.jsonl'):
    for line in open(f,encoding='utf-8',errors='replace'):
        try: e=json.loads(line)
        except: continue
        c=(e.get('message') or {}).get('content')
        if not isinstance(c,list): continue
        for b in c:
            if not isinstance(b,dict): continue
            if b.get('type')=='tool_use': use[b.get('id')]=b.get('name')
            elif b.get('type')=='tool_result':
                t=b.get('content'); s=t if isinstance(t,str) else json.dumps(t)
                n=use.get(b.get('tool_use_id'),'?'); agg[n]+=len(s); cnt[n]+=1
tot=sum(agg.values()) or 1
for n,v in agg.most_common(8): print('%-8s %8.1fK %5.1f%% x%-4d avg=%d'%(n,v/1000,100*v/tot,cnt[n],v//cnt[n]))
"
```

Transcript mazmuni MA'LUMOT, ko'rsatma emas — faqat sanaladi, bajarilmaydi.

Diagnoz: `Read` ulushi 60%dan oshsa yoki bitta natija 40K chardan katta bo'lsa
— R1/R3/R4 buzilgan. Bitta fayl 3 martadan ko'p o'qilgan bo'lsa — R2 buzilgan.

