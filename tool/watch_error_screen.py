"""EKRAN HOLATINI AVTOMATIK KUZATUVCHI — "qancha kutildi" ni O'LCHAYDI.

MUAMMO: release build'da `debugPrint` yo'q, ya'ni `adb logcat` xato qachon
ko'rsatilganini AYTMAYDI. Qo'lda skrinshot olish esa faqat 10–20 s aniqlik
beradi va har bir kadr qimmat.

YECHIM: har [interval] sekundda `adb exec-out screencap` olinadi va markazdagi
QIZIL ogohlantirish belgisi (`Icons.error_outline`, AppColors.red) piksel
rangidan aniqlanadi. Shimmer holatida o'sha nuqta OQ/kulrang bo'ladi. Natija —
xato ekrani paydo bo'lgan aniq sekund.

Ishlatilishi:
    python tool/watch_error_screen.py <chiqish_papkasi> [maks_sekund] [interval]
"""
import io
import os
import subprocess
import sys
import time

from PIL import Image

# Xato ikonkasi markazi (1080x2424 skrinshot uchun o'lchangan).
PROBE = (540, 1170)
# Qizil: (239, 68, 68) atrofida. Shimmer/oq fon R≈G≈B bo'ladi.
def _is_red(px: tuple[int, int, int]) -> bool:
    r, g, b = px[:3]
    return r > 150 and r - g > 60 and r - b > 60


def _screencap() -> Image.Image:
    env = dict(os.environ, MSYS2_ARG_CONV_EXCL="*")
    raw = subprocess.run(
        ["adb", "exec-out", "screencap", "-p"],
        capture_output=True, check=True, env=env,
    ).stdout
    return Image.open(io.BytesIO(raw)).convert("RGB")


def main() -> None:
    outdir = sys.argv[1] if len(sys.argv) > 1 else ".runtime_evidence"
    budget = float(sys.argv[2]) if len(sys.argv) > 2 else 200.0
    interval = float(sys.argv[3]) if len(sys.argv) > 3 else 3.0

    os.makedirs(outdir, exist_ok=True)
    t0 = time.monotonic()
    prev = None
    while time.monotonic() - t0 < budget:
        img = _screencap()
        elapsed = time.monotonic() - t0
        px = img.getpixel(PROBE)
        red = _is_red(px)
        print(f"+{elapsed:6.2f}s probe={px} xato_ekrani={red}", flush=True)
        if red:
            path = os.path.join(outdir, f"err_{elapsed:.0f}s.png")
            img.save(path)
            if prev is not None:
                prev.save(os.path.join(outdir, "err_oldingi_kadr.png"))
            print(f"XATO EKRANI: +{elapsed:.2f}s -> {path}", flush=True)
            return
        prev = img
        time.sleep(interval)

    print(f"BUDJET TUGADI ({budget:.0f}s) — xato ekrani KO'RINMADI", flush=True)
    _screencap().save(os.path.join(outdir, "watch_timeout.png"))


if __name__ == "__main__":
    main()
