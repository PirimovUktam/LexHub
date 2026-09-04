"""LexHub — web saytning BIRINCHI KO'RINISH vaqtini o'lchash (Playwright + CDP).

NIMA UCHUN KERAK: `curl` faqat TARMOQ tomonini o'lchaydi (TTFB, bayt). Hakam
ko'radigan vaqt esa unga QO'SHIMCHA: JS parse/compile + CanvasKit init +
Dart `main()` (Supabase.initialize + Hive + DI) + birinchi kadr. Bu skript
aynan shu zanjirni brauzerning O'ZINING Performance API'si bilan o'lchaydi.

O'LCHANADIGAN SIGNALLAR (hammasi navigatsiya boshidan, ms):
  ttfb  — `navigation.responseStart` (server javobi keldi)
  fcp   — `first-contentful-paint` = splash LOGOSI ko'rindi
  ff    — `flutter-first-frame` hodisasi = ILOVA ko'rindi (ASOSIY raqam)
  lcp   — eng katta element chizildi
  load  — `loadEventEnd`

XAVFSIZLIK: skript FAQAT berilgan URL'ni ochadi. Login QILMAYDI, forma
to'ldirMAYDI, hech qayerga ma'lumot yubormaydi, diskka faqat skrinshot
yozadi. Login yo'q -> PII yo'q, token yo'q. Brauzer har safar TOZA
kontekstda ochiladi (kesh bo'sh) — ya'ni "sovuq tashrif" o'lchanadi.

CHEGARA (§0): o'lchov BU HOSTda (Windows, Chromium headless). "telefon"
profili — CDP EMULYATSIYASI (4G kechikish/o'tkazuvchanlik + CPU 4x sekin),
HAQIQIY qurilma EMAS. Haqiqiy telefondagi raqam: NOT VERIFIED.

ISHLATISH:
  python tool/web_first_paint_probe.py [URL] [--runs N] [--shot FAYL]
"""

from __future__ import annotations

import statistics
import sys

from playwright.sync_api import sync_playwright

DEFAULT_URL = "https://lexhub-theta.vercel.app/"

# Telefon geometriyasi — loyihada allaqachon o'lchov birligi bo'lgan kenglik.
VIEWPORT = {"width": 390, "height": 844}
DSR = 3

PROFILES = {
    "cheklovsiz": None,
    "telefon_4g_cpu4x": {
        "net": {
            "offline": False,
            "latency": 150,  # ms RTT
            "downloadThroughput": int(9 * 1024 * 1024 / 8),  # 9 Mbit/s
            "uploadThroughput": int(1.5 * 1024 * 1024 / 8),
        },
        "cpu": 4,
    },
}

# Kuzatuvchilar sahifa kodidan OLDIN o'rnatiladi, aks holda `flutter-first-frame`
# hodisasi biz tinglashdan oldin o'tib ketadi.
INIT_JS = """
window.__ff = null;
window.__lcp = null;
window.addEventListener('flutter-first-frame', () => {
  if (window.__ff === null) window.__ff = performance.now();
});
try {
  new PerformanceObserver((l) => {
    for (const e of l.getEntries()) window.__lcp = e.startTime;
  }).observe({type: 'largest-contentful-paint', buffered: true});
} catch (e) {}
"""

MEASURE_JS = """() => {
  const nav = performance.getEntriesByType('navigation')[0];
  const paint = {};
  for (const p of performance.getEntriesByType('paint')) {
    paint[p.name] = Math.round(p.startTime);
  }
  const keep = /main\\.dart\\.js|flutter_bootstrap\\.js|canvaskit\\.(js|wasm)|\\.woff2|\\.otf/;
  const res = performance.getEntriesByType('resource')
    .filter((r) => keep.test(r.name))
    .map((r) => ({
      n: r.name.split('/').pop().slice(0, 34),
      s: Math.round(r.startTime),
      e: Math.round(r.responseEnd),
      i: r.initiatorType,
      b: r.transferSize,
    }));
  return {
    ttfb: Math.round(nav.responseStart),
    dcl: Math.round(nav.domContentLoadedEventEnd),
    load: Math.round(nav.loadEventEnd),
    fcp: paint['first-contentful-paint'] ?? null,
    ff: window.__ff === null ? null : Math.round(window.__ff),
    lcp: window.__lcp === null ? null : Math.round(window.__lcp),
    splashInDom: !!document.getElementById('splash'),
    res: res,
  };
}"""


def run_once(browser, url: str, profile: dict | None, shot: str | None) -> dict:
    """Bitta SOVUQ tashrif: yangi kontekst (bo'sh kesh) -> o'lchov -> yopish."""
    ctx = browser.new_context(
        viewport=VIEWPORT,
        device_scale_factor=DSR,
        is_mobile=True,
        has_touch=True,
    )
    try:
        page = ctx.new_page()
        page.add_init_script(INIT_JS)
        cdp = ctx.new_cdp_session(page)
        if profile is not None:
            cdp.send("Network.enable")
            cdp.send("Network.emulateNetworkConditions", profile["net"])
            cdp.send("Emulation.setCPUThrottlingRate", {"rate": profile["cpu"]})
        page.goto(url, wait_until="commit", timeout=90_000)
        ff_ok = True
        try:
            page.wait_for_function("() => window.__ff !== null", timeout=90_000)
        except Exception:
            ff_ok = False
        # Birinchi kadrdan keyin LCP hali ko'chishi mumkin — 400 ms kutiladi.
        page.wait_for_timeout(400)
        data = page.evaluate(MEASURE_JS)
        data["ff_ok"] = ff_ok
        if shot:
            page.screenshot(path=shot)
        return data
    finally:
        ctx.close()


def fmt_row(tag: str, d: dict) -> str:
    def v(key: str) -> str:
        x = d.get(key)
        return "     -" if x is None else f"{x:6d}"

    return (
        f"{tag:<26} ttfb={v('ttfb')}  fcp={v('fcp')}  "
        f"ff={v('ff')}  lcp={v('lcp')}  load={v('load')}"
        f"{'' if d.get('ff_ok') else '   [flutter-first-frame KELMADI]'}"
    )


def main() -> int:
    args = [a for a in sys.argv[1:]]
    url = DEFAULT_URL
    runs = 2
    shot = None
    rest = []
    i = 0
    while i < len(args):
        if args[i] == "--runs":
            runs = int(args[i + 1])
            i += 2
        elif args[i] == "--shot":
            shot = args[i + 1]
            i += 2
        else:
            rest.append(args[i])
            i += 1
    if rest:
        url = rest[0]

    print(f"URL:      {url}")
    print(f"viewport: {VIEWPORT['width']}x{VIEWPORT['height']} dsr={DSR} (mobile)")
    print(f"runs:     {runs} / profil, har biri SOVUQ (yangi kontekst)")
    print("birlik:   ms, navigatsiya boshidan\n")

    with sync_playwright() as p:
        browser = p.chromium.launch()
        try:
            for pname, profile in PROFILES.items():
                rows = []
                for n in range(runs):
                    want_shot = shot if (profile is not None and n == runs - 1) else None
                    d = run_once(browser, url, profile, want_shot)
                    rows.append(d)
                    print(fmt_row(f"{pname} #{n + 1}", d))
                ffs = [r["ff"] for r in rows if r.get("ff") is not None]
                if len(ffs) > 1:
                    print(
                        f"{'-> ff mediana':<26} {int(statistics.median(ffs)):6d} ms"
                        f"  (min {min(ffs)}, max {max(ffs)})"
                    )
                last = rows[-1]
                print(f"   splash DOM'da qoldimi: {last['splashInDom']}")
                print("   zanjir (fayl | boshlandi -> tugadi | initiator | bayt):")
                for r in last["res"]:
                    print(
                        f"     {r['n']:<34} {r['s']:6d} -> {r['e']:6d}"
                        f"  {r['i']:<8} {r['b']}"
                    )
                print()
        finally:
            browser.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
