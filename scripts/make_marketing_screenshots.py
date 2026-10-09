#!/usr/bin/env python3
"""App Store 마케팅 스크린샷: 원본 캡처 + 헤드라인 → HTML → 헤드리스 Chrome (appstore-assets 스킬).

사용법: python3 scripts/make_marketing_screenshots.py [언어 ...]   (없으면 전부)

자리
  docs/screenshots/raw/<언어>/NN-….png          원본 캡처 (1320x2868, 스토어에 안 올라감)
  docs/screenshots/marketing/<로케일>/NN-….png   제출본 1242x2688 — DeployBar 가 이 폴더를 그대로 올린다
슬라이드마다 배치(layout)를 달리한다: hero-bleed · left-text · text-bottom · flat-rotate · dark
"""
import subprocess, sys, pathlib, tempfile, time

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "docs" / "screenshots" / "raw"
OUT = ROOT / "docs" / "screenshots" / "marketing"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 1242, 2688   # 이 계정의 아이폰 제출 규격

# 앱 언어 → App Store 로케일
STORE = {"ko": "ko"}

# 파일 · 배치 · 언어별 (헤드라인, 보조 문장)
SHOTS = [
    ("01-home.png",      "hero-bleed",  {"ko": ("지르기 전에<br>쿨타임부터", "배달도 쇼핑도 쿨타임이 끝나야 다시")}),
    ("02-break.png",     "left-text",   {"ko": ("쿨타임 중엔<br>한 번 더 멈칫", "깨면 준수율이 내려간다고 알려줘요")}),
    ("03-stats.png",     "text-bottom", {"ko": ("얼마나 참았는지<br>숫자로 보여요", "아이템별 준수율과 사용 기록을 한눈에")}),
    ("04-templates.png", "dark",        {"ko": ("여행부터 배달까지<br>탭 한 번으로 추가", "자주 쓰는 쿨타임을 골라 바로 시작해요")}),
]

# 색은 헤더·검색 결과 그림(make_creative_assets.py)과 맞춘다.
THEME = dict(bg="#F2F2F7", ink="#16161A", sub="#76767E", dark_bg="#16161A", dark_ink="#ffffff",
             dark_sub="#9a9aa3", frame="#1b1b1f", rim="#c9c9d1", glow="rgba(46,204,112,.28)")

BASE_CSS = """
* { margin:0; padding:0; box-sizing:border-box; }
html,body { width:%(W)dpx; height:%(H)dpx; overflow:hidden; }
body { background:%(bg)s; font-family:-apple-system, "Apple SD Gothic Neo", "Hiragino Sans", sans-serif; position:relative; }
.headline { font-size:96px; font-weight:800; color:%(ink)s; letter-spacing:-2px; line-height:1.22; text-wrap:balance; }
.sub { font-size:50px; font-weight:500; color:%(sub)s; letter-spacing:-1px; line-height:1.35; text-wrap:balance; }
:lang(ko) .headline, :lang(ko) .sub { word-break:keep-all; }
.phone { background:%(frame)s; border-radius:112px; border:3px solid %(rim)s; padding:24px;
  box-shadow: 60px 90px 120px rgba(0,0,0,.24), 20px 30px 50px rgba(0,0,0,.14); }
.phone img { width:100%%; display:block; border-radius:89px; }
"""

LAYOUTS = {
    "hero-bleed": """
.headline { text-align:center; margin-top:270px; padding:0 70px; }
.sub { text-align:center; margin-top:46px; padding:0 80px; }
.wrap { display:flex; justify-content:center; margin-top:130px; }
.phone { width:970px; }
""",
    "left-text": """
.headline { text-align:left; margin:280px 90px 0 105px; }
.sub { text-align:left; margin:44px 90px 0 109px; }
.wrap { perspective:2600px; perspective-origin:30% 30%; position:absolute; left:290px; top:960px; }
.phone { width:815px; transform:rotateY(16deg) rotateX(2deg); }
""",
    "text-bottom": """
.wrap { perspective:2800px; perspective-origin:50% 40%; display:flex; justify-content:center; margin-top:160px; }
.phone { width:850px; transform:rotateY(-10deg) rotateX(2deg); }
.headline { text-align:center; margin-top:110px; padding:0 70px; }
.sub { text-align:center; margin-top:44px; padding:0 80px; }
""",
    "flat-rotate": """
.headline { text-align:center; margin-top:250px; padding:0 70px; }
.sub { text-align:center; margin-top:46px; padding:0 80px; }
.wrap { position:absolute; left:115px; top:980px; }
.phone { width:980px; transform:rotate(-6deg); }
""",
    "dark": """
body { background:%(dark_bg)s; }
.headline { color:%(dark_ink)s; text-align:center; margin-top:270px; padding:0 70px; }
.sub { color:%(dark_sub)s; text-align:center; margin-top:46px; padding:0 80px; }
.wrap { display:flex; justify-content:center; margin-top:130px; }
.phone { width:900px; border-color:#48484e; box-shadow: 0 0 160px %(glow)s, 40px 70px 110px rgba(0,0,0,.55); }
""",
}

TEXT_FIRST = '<div class="headline">{h}</div><div class="sub">{s}</div><div class="wrap"><div class="phone"><img src="{img}"></div></div>'
PHONE_FIRST = '<div class="wrap"><div class="phone"><img src="{img}"></div></div><div class="headline">{h}</div><div class="sub">{s}</div>'
HTML = '<!doctype html><html lang="{lang}"><head><meta charset="utf-8"><style>{css}</style></head><body>{body}</body></html>'


def raw_for(lang, fname):
    p = RAW / lang / fname
    return p if p.exists() else RAW / fname


def main(langs):
    tmp = pathlib.Path(tempfile.mkdtemp())
    vals = dict(THEME, W=W, H=H)
    for lang in langs:
        out_dir = OUT / STORE[lang]
        out_dir.mkdir(parents=True, exist_ok=True)
        for fname, layout, texts in SHOTS:
            h, s = texts[lang]
            src = raw_for(lang, fname)
            assert src.exists(), f"원본 없음: {src}"
            tpl = PHONE_FIRST if layout == "text-bottom" else TEXT_FIRST
            css = BASE_CSS % vals + LAYOUTS[layout] % vals if "%(" in LAYOUTS[layout] else BASE_CSS % vals + LAYOUTS[layout]
            html = tmp / f"{lang}-{fname}.html"
            html.write_text(HTML.format(lang=lang, css=css, body=tpl.format(h=h, s=s, img=src.as_uri())), encoding="utf-8")
            out = out_dir / fname
            # Chrome 은 그림을 다 쓰고도 안 끝나거나, 아무것도 안 그리고 끝날 때가 있다.
            # 파일이 생기고 크기가 멈추면 다 된 것으로 보고 닫는다. 세 번까지 한다.
            for _ in range(3):
                out.unlink(missing_ok=True)
                proc = subprocess.Popen([CHROME, "--headless=new", f"--screenshot={out}", f"--window-size={W},{H}",
                                         "--force-device-scale-factor=1", "--hide-scrollbars", "--disable-gpu",
                                         "--no-first-run", "--disable-extensions", "--disable-background-networking",
                                         "--virtual-time-budget=3000", "--allow-file-access-from-files",
                                         f"--user-data-dir={tmp / 'chrome'}", html.as_uri()],
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                size, deadline = -1, time.time() + 90
                while time.time() < deadline:
                    time.sleep(1)
                    now = out.stat().st_size if out.exists() else -1
                    if now > 0 and now == size:
                        break
                    if proc.poll() is not None and now <= 0:
                        break
                    size = now
                proc.kill(); proc.wait()
                if out.exists() and out.stat().st_size > 0:
                    break
            else:
                raise SystemExit(f"Chrome 이 그리지 못했다: {out}")
            print("rendered", out.relative_to(ROOT))


if __name__ == "__main__":
    main(sys.argv[1:] or list(STORE))
