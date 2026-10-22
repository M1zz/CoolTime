#!/bin/sh
# 스토어 스크린샷 원본 캡처 — 언어마다 예시 데이터를 넣고 네 화면 + 다크 홈을 찍는다.
#
# 사용법: sh scripts/capture_screenshots.sh <시뮬레이터 UDID> <앱 경로(.app, Debug)> [언어 ...]
#   - 시뮬레이터는 미리 부팅해 둔다(1320x2868 기기: iPhone 17 Pro Max 등).
#   - 앱은 Debug 빌드여야 한다(-screenshotSeed 는 DEBUG 에만 있다. CoolTimeApp.swift 의 ScreenshotSeed).
#   - 언어를 안 주면 ko 를 뺀 전부.
#
# 결과
#   docs/screenshots/raw/<언어>/01-home.png 02-break.png 03-stats.png 04-templates.png
#   docs/screenshots/raw/creative/<언어>/01-home.png 02-home-dark.png
# 다음: python3 scripts/make_marketing_screenshots.py <언어> · python3 scripts/make_creative_assets.py <언어>
set -e
SIM="$1"; APP="$2"; shift 2
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE=com.Ysoup.CoolTime
LANGS="${*:-en en-GB zh-Hans zh-Hant ja ru es de fr it pt-BR th vi cs da el fi id nb nl pl sv tr}"

locale_of() {
  case "$1" in
    ko) echo ko_KR ;; en) echo en_US ;; en-GB) echo en_GB ;; zh-Hans) echo zh_CN ;; zh-Hant) echo zh_TW ;;
    ja) echo ja_JP ;; ru) echo ru_RU ;; es) echo es_ES ;; de) echo de_DE ;; fr) echo fr_FR ;; it) echo it_IT ;;
    pt-BR) echo pt_BR ;; th) echo th_TH ;; vi) echo vi_VN ;; cs) echo cs_CZ ;; da) echo da_DK ;; el) echo el_GR ;;
    fi) echo fi_FI ;; id) echo id_ID ;; nb) echo nb_NO ;; nl) echo nl_NL ;; pl) echo pl_PL ;; sv) echo sv_SE ;;
    tr) echo tr_TR ;; *) echo "$1" ;;
  esac
}

xcrun simctl install "$SIM" "$APP"
xcrun simctl status_bar "$SIM" override --time 9:41 --dataNetwork wifi --wifiBars 3 --cellularMode active \
  --cellularBars 4 --batteryState charged --batteryLevel 100

shot() { # 언어 화면 파일 [화면이름]
  xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
  ARGS="-AppleLanguages ($1) -AppleLocale $(locale_of "$1") -hasCompletedOnboarding YES -screenshotSeed"
  [ -n "$4" ] && ARGS="$ARGS -screenshotScreen $4"
  # shellcheck disable=SC2086
  xcrun simctl launch "$SIM" "$BUNDLE" $ARGS >/dev/null
  sleep 6   # 부하가 있으면 늦게 그린다 — 시트 애니메이션까지 끝나길 기다린다
  xcrun simctl io "$SIM" screenshot --type=png "$3" >/dev/null 2>&1
  echo "  $3"
}

for L in $LANGS; do
  echo "▶ $L"
  RAW="$ROOT/docs/screenshots/raw/$L"; CRE="$ROOT/docs/screenshots/raw/creative/$L"
  mkdir -p "$RAW" "$CRE"
  xcrun simctl ui "$SIM" appearance light
  shot "$L" home "$RAW/01-home.png"
  shot "$L" break "$RAW/02-break.png" break
  shot "$L" stats "$RAW/03-stats.png" stats
  shot "$L" templates "$RAW/04-templates.png" templates
  cp "$RAW/01-home.png" "$CRE/01-home.png"
  xcrun simctl ui "$SIM" appearance dark
  shot "$L" home "$CRE/02-home-dark.png"
  xcrun simctl ui "$SIM" appearance light
done
xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null || true
