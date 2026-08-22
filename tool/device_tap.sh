#!/usr/bin/env bash
# LexHub — real device (MIUI) uchun RAW TOUCH injektsiya.
#
# Sabab: MIUI `adb shell input tap` ni bloklaydi:
#   SecurityException: Injecting to another application requires
#   INJECT_EVENTS permission
# `shell` foydalanuvchisi `input` (gid 1004) guruhida bo'lgani uchun
# /dev/input/event3 (NVTCapacitiveTouchScreen) ga to'g'ridan-to'g'ri
# kernel-level event yuborish mumkin. Koordinatalar 1:1 (0..1079, 0..2399).
#
# Foydalanish:
#   tool/device_tap.sh tap  X Y
#   tool/device_tap.sh swipe X1 Y1 X2 Y2 [STEPS]
set -euo pipefail

DEV=/dev/input/event3
EV_SYN=0; EV_KEY=1; EV_ABS=3
SYN_REPORT=0; BTN_TOUCH=330
MT_SLOT=47; MT_TOUCH_MAJOR=48; MT_POS_X=53; MT_POS_Y=54; MT_TRACKING_ID=57; MT_PRESSURE=58
TRACK=$(( (RANDOM % 60000) + 100 ))

down() { # x y
  cat <<EOF
sendevent $DEV $EV_ABS $MT_SLOT 0
sendevent $DEV $EV_ABS $MT_TRACKING_ID $TRACK
sendevent $DEV $EV_KEY $BTN_TOUCH 1
sendevent $DEV $EV_ABS $MT_TOUCH_MAJOR 8
sendevent $DEV $EV_ABS $MT_PRESSURE 120
sendevent $DEV $EV_ABS $MT_POS_X $1
sendevent $DEV $EV_ABS $MT_POS_Y $2
sendevent $DEV $EV_SYN $SYN_REPORT 0
EOF
}

move() { # x y
  cat <<EOF
sendevent $DEV $EV_ABS $MT_SLOT 0
sendevent $DEV $EV_ABS $MT_POS_X $1
sendevent $DEV $EV_ABS $MT_POS_Y $2
sendevent $DEV $EV_SYN $SYN_REPORT 0
EOF
}

up() {
  cat <<EOF
sendevent $DEV $EV_ABS $MT_SLOT 0
sendevent $DEV $EV_ABS $MT_TRACKING_ID -1
sendevent $DEV $EV_KEY $BTN_TOUCH 0
sendevent $DEV $EV_SYN $SYN_REPORT 0
EOF
}

case "${1:-}" in
  tap)
    X=$2; Y=$3
    { down "$X" "$Y"; echo "sleep 0.08"; up; } | adb shell
    ;;
  swipe)
    X1=$2; Y1=$3; X2=$4; Y2=$5; STEPS=${6:-12}
    {
      down "$X1" "$Y1"
      for i in $(seq 1 "$STEPS"); do
        CX=$(( X1 + (X2 - X1) * i / STEPS ))
        CY=$(( Y1 + (Y2 - Y1) * i / STEPS ))
        move "$CX" "$CY"
        echo "sleep 0.02"
      done
      up
    } | adb shell
    ;;
  *)
    echo "usage: $0 tap X Y | $0 swipe X1 Y1 X2 Y2 [STEPS]" >&2
    exit 2
    ;;
esac
