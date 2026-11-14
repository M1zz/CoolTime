#!/bin/zsh
# 애플워치 스토어 스크린샷 — 꾸미지 않은 화면을 docs/screenshots/watch/<언어>/ 에 둔다 (416×496, Series 46mm).
#
# 사용법: zsh scripts/capture_watch.sh <워치 시뮬레이터 UDID> [언어 ...]   (언어를 안 주면 24개 모두)
#   - Debug 빌드가 build/dd/Build/Products/Debug-watchsimulator/CoolTimeWatch.app 에 있어야 한다(-watchDemo 는 DEBUG 전용).
# 장면: list(쿨타임 목록) · detail(한 항목의 링과 [썼어요])
set -u
cd "$(dirname "$0")/.."

DEV=$1; shift
APP=build/dd/Build/Products/Debug-watchsimulator/CoolTimeWatch.app
BUNDLE=com.Ysoup.CoolTime.watchkitapp
ALL=(ko en en-GB ja zh-Hans zh-Hant ru es de fr it pt-BR th vi cs da el fi id nb nl pl sv tr)
if (( $# )); then LANGS=($@); else LANGS=($ALL); fi

locale_of() {
  case $1 in
    ko) echo ko_KR ;; en) echo en_US ;; en-GB) echo en_GB ;; zh-Hans) echo zh_CN ;; zh-Hant) echo zh_TW ;;
    ja) echo ja_JP ;; ru) echo ru_RU ;; es) echo es_ES ;; de) echo de_DE ;; fr) echo fr_FR ;; it) echo it_IT ;;
    pt-BR) echo pt_BR ;; th) echo th_TH ;; vi) echo vi_VN ;; cs) echo cs_CZ ;; da) echo da_DK ;; el) echo el_GR ;;
    fi) echo fi_FI ;; id) echo id_ID ;; nb) echo nb_NO ;; nl) echo nl_NL ;; pl) echo pl_PL ;; sv) echo sv_SE ;;
    tr) echo tr_TR ;; *) echo en_US ;;
  esac
}
t() { perl -e 'alarm shift; exec @ARGV' "$@"; }   # 시뮬레이터가 멈추면 기다리지 않는다

t 120 xcrun simctl boot $DEV 2>/dev/null
t 300 xcrun simctl bootstatus $DEV -b >/dev/null
t 60 xcrun simctl status_bar $DEV override --time 9:41 >/dev/null 2>&1
t 300 xcrun simctl install $DEV $APP || { echo "설치 실패"; exit 1; }

for lang in $LANGS; do
  echo "▸ $lang"
  out=docs/screenshots/watch/$lang; mkdir -p $out
  n=0
  for scene in list detail; do
    n=$((n+1))
    open=NO; [[ $scene == detail ]] && open=YES
    file=$out/watch-0$n-$scene.png
    for try in 1 2 3; do
      t 120 xcrun simctl launch --terminate-running-process $DEV $BUNDLE \
        -watchDemo YES -watchDemoOpen $open -AppleLanguages "($lang)" -AppleLocale $(locale_of $lang) >/dev/null 2>&1 || continue
      sleep 6
      tmp=${TMPDIR:-/tmp}/cooltime-watch-$$.png
      t 60 xcrun simctl io $DEV screenshot $tmp >/dev/null 2>&1 && mv -f $tmp $file && break
    done
    [[ -f $file ]] && echo "  $file" || echo "  ✗ $file"
  done
done
