# LexHub — PROBE HISOBI KALITLARI (bitta joyda).
#
# NIMA UCHUN BOR: `tool/probe_legal_ai_latency.py` va
# `tool/probe_legal_ai_model.py` ikkovi ham JONLI Supabase'ga probe hisobi
# bilan kiradi. Ilgari parol IKKI FAYLDA HAM ochiq yozilgandi (zaif,
# hammaga ma'lum qiymat) — repo esa OMMAVIY, ya'ni uni ko'rgan har kim shu
# tasdiqlangan hisob bilan kirib, yozish huquqi bilan ishlashi mumkin edi.
# Eski qiymat MANBADA QAYTA YOZILMAYDI: `test/core/security/`
# `no_leaked_test_password_test.dart` uning qaytishini bloklaydi.
#
# 2026-09-20: authorized production H01 rotation and global revoke verified.
# Old password/refresh rejected; existing user data preserved. The ignored
# env/probe.json now stores PROBE_PASSWORD_CREDENTIAL_TARGET, not the password.
# The value stays in Windows Credential Manager or an explicit CI environment.
# Historical credential exposure still requires a separate history decision.
#
# FAIL-CLOSED: fayl yoki kalit bo'lmasa vosita BLOCKED bo'lib to'xtaydi.
# Sukut bo'yicha parol, "shunday ishlayveradi" degan soxta muvaffaqiyat YO'Q.
import json
import os

CREDS_PATH = 'env/probe.json'


def _stored_password(target):
    """Read the named probe secret; never return/log credential-manager metadata."""
    if not isinstance(target, str) or not target.startswith('LexHub:probe:'):
        raise SystemExit('BLOCKED: invalid probe secret reference')
    if os.name != 'nt':
        raise SystemExit('BLOCKED: inject LEXHUB_PROBE_PASSWORD on this platform')
    import ctypes
    from ctypes import wintypes as w

    class Credential(ctypes.Structure):
        _fields_ = [('Flags', w.DWORD), ('Type', w.DWORD), ('TargetName', w.LPWSTR),
                    ('Comment', w.LPWSTR), ('LastWritten', w.FILETIME),
                    ('CredentialBlobSize', w.DWORD), ('CredentialBlob', ctypes.POINTER(w.BYTE)),
                    ('Persist', w.DWORD), ('AttributeCount', w.DWORD),
                    ('Attributes', ctypes.c_void_p), ('TargetAlias', w.LPWSTR), ('UserName', w.LPWSTR)]
    api = ctypes.WinDLL('Advapi32.dll', use_last_error=True)
    api.CredReadW.argtypes = [w.LPCWSTR, w.DWORD, w.DWORD, ctypes.POINTER(ctypes.POINTER(Credential))]
    api.CredReadW.restype = w.BOOL
    api.CredFree.argtypes = [ctypes.c_void_p]
    value = ctypes.POINTER(Credential)()
    if not api.CredReadW(target, 1, 0, ctypes.byref(value)):
        raise SystemExit('BLOCKED: probe secret reference is unavailable')
    try:
        return ctypes.string_at(value.contents.CredentialBlob,
                                value.contents.CredentialBlobSize).decode('utf-8')
    finally:
        api.CredFree(value)


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
    with open(CREDS_PATH, encoding='utf-8') as file:
        cfg = json.load(file)
    email = env_email or cfg.get('PROBE_EMAIL', '')
    password = env_pw or (_stored_password(cfg['PROBE_PASSWORD_CREDENTIAL_TARGET'])
                          if cfg.get('PROBE_PASSWORD_CREDENTIAL_TARGET')
                          else cfg.get('PROBE_PASSWORD', ''))
    if not email or not password:
        raise SystemExit(
            f'BLOCKED: {CREDS_PATH} da PROBE_EMAIL yoki PROBE_PASSWORD yo\'q.')
    return email, password
