# LexHub — PROBE HISOBI KALITLARI (bitta joyda).
#
# NIMA UCHUN BOR: `tool/probe_legal_ai_latency.py` va
# `tool/probe_legal_ai_model.py` ikkovi ham JONLI Supabase'ga probe hisobi
# bilan kiradi. Ilgari parol IKKI FAYLDA HAM ochiq yozilgandi
# (`Password123!`) — repo ko'rgan har kim shu tasdiqlangan hisob bilan
# kirib, yozish huquqi bilan ishlashi mumkin edi.
#
# TUZATISH (2026-09-04): parol JONLI bazada almashtirildi (eski qiymat endi
# `HTTP 400` — O'LCHANDI) va yangi qiymat FAQAT `env/probe.json` da turadi.
# U `.gitignore:21` (`env/*.json`) bilan qulflangan, ya'ni repoga TUSHMAYDI.
#
# FAIL-CLOSED: fayl yoki kalit bo'lmasa vosita BLOCKED bo'lib to'xtaydi.
# Sukut bo'yicha parol, "shunday ishlayveradi" degan soxta muvaffaqiyat YO'Q.
import json
import os

CREDS_PATH = 'env/probe.json'


def probe_credentials():
    """`(email, password)` — `env/probe.json` yoki muhit o'zgaruvchilaridan.

    Muhit o'zgaruvchilari fayldan USTUN turadi:
      `LEXHUB_PROBE_EMAIL`, `LEXHUB_PROBE_PASSWORD`.
    """
    env_email = os.environ.get('LEXHUB_PROBE_EMAIL')
    env_pw = os.environ.get('LEXHUB_PROBE_PASSWORD')
    if env_email and env_pw:
        return env_email, env_pw

    if not os.path.exists(CREDS_PATH):
        raise SystemExit(
            f'BLOCKED: {CREDS_PATH} topilmadi (u gitignored — SIR).\n'
            '  Format: {"PROBE_EMAIL": "...", "PROBE_PASSWORD": "..."}\n'
            '  Yoki: LEXHUB_PROBE_EMAIL=... LEXHUB_PROBE_PASSWORD=... '
            'bilan ishga tushiring.')
    cfg = json.load(open(CREDS_PATH, encoding='utf-8'))
    email = env_email or cfg.get('PROBE_EMAIL', '')
    password = env_pw or cfg.get('PROBE_PASSWORD', '')
    if not email or not password:
        raise SystemExit(
            f'BLOCKED: {CREDS_PATH} da PROBE_EMAIL yoki PROBE_PASSWORD yo\'q.')
    return email, password
