# LexHub - P0 configuration hardening verification harness
#
# Maqsad: 15-bosqichni (flutter analyze + flutter test) REAL bajarish va
# natijani log faylga yozish. Agent VM'da flutter/dart binary yo'q, shuning
# uchun bu skript FAQAT user mashinasida ishlatiladi.
#
# Ishlatish (PowerShell, repo root'dan):
#   powershell -ExecutionPolicy Bypass -File tool\verify_p0_config.ps1
#   powershell -ExecutionPolicy Bypass -File tool\verify_p0_config.ps1 -Full
#
# -Full berilsa test/integration/* ham ishga tushadi. DIQQAT: o'sha fayllar
# REAL Supabase cloud proyektiga yozadi (data mutatsiya qiladi). Ular
# `test/support/live_gate.dart` gate'i ostida: LEXHUB_LIVE_WRITE_TESTS=true
# berilmasa OSHKORA skip (sababi reporter'da ko'rinadi), jim PASS emas.

[CmdletBinding()]
param(
    [switch]$Full
)

$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $repoRoot

$logDir = Join-Path $repoRoot 'tool\logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$log = Join-Path $logDir "p0_config_verify_$stamp.log"

function Log($msg) {
    Write-Host $msg
    Add-Content -Path $log -Value $msg -Encoding UTF8
}

function Run($title, $exe, $argList) {
    Log ''
    Log "=============================================================="
    Log "### $title"
    Log "### CMD: $exe $($argList -join ' ')"
    Log "### START: $(Get-Date -Format 'HH:mm:ss')"
    Log "=============================================================="
    & $exe @argList 2>&1 | ForEach-Object { Log $_ }
    $code = $LASTEXITCODE
    Log "### EXIT CODE: $code"
    return $code
}

Log "LexHub P0 configuration verification"
Log "repo    : $repoRoot"
Log "log     : $log"
Log "started : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# --- Preconditions -----------------------------------------------------
$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter) {
    Log 'FATAL: `flutter` PATH ichida topilmadi. Skript to`xtatildi.'
    exit 2
}
Log "flutter : $($flutter.Source)"

if (-not (Test-Path 'env\dev.json')) {
    Log 'FATAL: env\dev.json yo`q. env\dev.json.example dan nusxa oling va'
    Log '       real qiymatlarni to`ldiring (bu fayl gitignored).'
    exit 2
}

# Secret'larni CHIQARMAYMIZ - faqat kalit nomlari va mavjudligi.
$devKeys = (Get-Content 'env\dev.json' -Raw | ConvertFrom-Json)
foreach ($p in $devKeys.PSObject.Properties) {
    $present = if ([string]::IsNullOrEmpty([string]$p.Value)) { 'EMPTY' } else { 'present' }
    Log ("env/dev.json -> {0,-20} {1}" -f $p.Name, $present)
}

# --- Steps -------------------------------------------------------------
$results = [ordered]@{}

$results['flutter --version'] = Run 'flutter --version' 'flutter' @('--version')
$results['flutter pub get']   = Run 'flutter pub get'   'flutter' @('pub', 'get')
# Ataylab qat'iy rejim: info-level lint ham exit code'ni buzadi. Yumshatmaymiz.
$results['flutter analyze']   = Run 'flutter analyze'   'flutter' @('analyze')

# P0 scope: config kontrakti + fail-fast ekran. Bu YASHIL bo'lishi SHART.
$results['flutter test (P0 config scope)'] = Run 'flutter test test/core/config' 'flutter' @(
    'test', '--dart-define-from-file=env/dev.json', 'test/core/config', '--reporter', 'expanded'
)

# Butun unit/widget suite. `flutter test` (yo'lsiz) endi XAVFSIZ: barcha
# test/integration/* fayllari `test/support/live_gate.dart` gate'i ostida,
# ya'ni LEXHUB_LIVE_WRITE_TESTS=true bo'lmasa OSHKORA skip bo'ladi.
$results['flutter test (default, production TEGILMAYDI)'] = Run 'flutter test' 'flutter' @(
    'test', '--reporter', 'compact'
)

if ($Full) {
    Log ''
    Log 'WARNING: test/integration/* REAL Supabase cloud proyektiga yozadi.'
    $results['flutter test (integration, REAL CLOUD)'] = Run 'flutter test test/integration' 'flutter' @(
        'test', '--dart-define-from-file=env/prod.json',
        '--dart-define=LEXHUB_LIVE_WRITE_TESTS=true',
        'test/integration', '--reporter', 'compact'
    )
} else {
    Log ''
    Log 'GATED (live_gate.dart, oshkora skip): test/integration/* - real cloud mutation.'
    Log 'Ishga tushirish uchun: tool\verify_p0_config.ps1 -Full'
}

# --- Summary -----------------------------------------------------------
Log ''
Log '=============================================================='
Log '### SUMMARY (exit code 0 = PASS)'
Log '=============================================================='
foreach ($k in $results.Keys) {
    $verdict = if ($results[$k] -eq 0) { 'PASS' } else { "FAIL ($($results[$k]))" }
    Log ("{0,-52} {1}" -f $k, $verdict)
}
Log ''
Log "To`liq log: $log"
Log 'Shu faylni menga yuboring - 15-bosqich statusi BLOCKED dan VERIFIED ga o`tadi.'
