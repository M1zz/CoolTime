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

# 파일 · 배치 · 언어별 (헤드라인, 보조 문장). 용어는 그 언어 앱 화면의 말(쿨타임 · 준수율)에 맞춘다.
TEXTS = {
    "ko": [("지르기 전에<br>쿨타임부터", "배달도 쇼핑도 쿨타임이 끝나야 다시"), ("쿨타임 중엔<br>한 번 더 멈칫", "깨면 준수율이 내려간다고 알려줘요"),
           ("얼마나 참았는지<br>숫자로 보여요", "아이템별 준수율과 사용 기록을 한눈에"), ("여행부터 배달까지<br>탭 한 번으로 추가", "자주 쓰는 쿨타임을 골라 바로 시작해요")],
    "en": [("Cooldown first,<br>then splurge", "Delivery and shopping wait until the cooldown ends"), ("One more pause<br>during a cooldown", "We warn you that breaking it lowers your compliance"),
           ("See how long<br>you held out", "Compliance by item and your usage history at a glance"), ("From travel to delivery<br>add with one tap", "Pick common cooldowns and start right away")],
    "en-GB": [("Cooldown first,<br>then splurge", "Takeaways and shopping wait until the cooldown ends"), ("One more pause<br>during a cooldown", "We warn you that breaking it lowers your compliance"),
              ("See how long<br>you held out", "Compliance by item and your history at a glance"), ("From holidays to takeaways<br>add with one tap", "Pick a common cooldown and start straight away")],
    "zh-Hans": [("先冷却<br>再剁手", "外卖和购物，都等冷却结束再说"), ("冷却中<br>再停一停", "打破冷却会提醒你遵守率将下降"),
                ("忍住了多久<br>数字告诉你", "各项遵守率和使用记录一目了然"), ("从旅行到外卖<br>一点就能添加", "挑选常用冷却，立刻开始")],
    "zh-Hant": [("先冷卻<br>再下手", "外送和購物，都等冷卻結束再說"), ("冷卻中<br>再停一下", "打破冷卻會提醒你遵守率將下降"),
                ("忍住了多久<br>數字告訴你", "各項遵守率與使用紀錄一目了然"), ("從旅行到外送<br>點一下就加入", "挑選常用的冷卻，馬上開始")],
    "ja": [("買う前に<br>クールタイムから", "デリバリーも買い物もクールタイムが終わってから"), ("クールタイム中は<br>もう一度立ち止まる", "解除すると達成率が下がることをお知らせ"),
           ("どれだけ我慢したか<br>数字でわかる", "項目ごとの達成率と利用履歴をひと目で"), ("旅行からデリバリーまで<br>タップで追加", "よく使うクールタイムを選んですぐスタート")],
    "ru": [("Сначала перезарядка,<br>потом покупка", "Доставка и шопинг ждут конца перезарядки"), ("На перезарядке —<br>ещё одна пауза", "Предупредим, что срыв снизит соблюдение"),
           ("Сколько вы<br>продержались", "Соблюдение по каждому пункту и история в одном месте"), ("От поездок до доставки<br>в одно касание", "Выберите готовую перезарядку и начните сразу")],
    "es": [("Primero la espera,<br>luego el capricho", "Compras y comida a domicilio esperan a que acabe"), ("En espera,<br>piénsalo otra vez", "Te avisamos de que romperla baja tu cumplimiento"),
           ("Mira cuánto<br>has aguantado", "Cumplimiento por elemento e historial de un vistazo"), ("De viajes a comida a domicilio<br>con un toque", "Elige esperas habituales y empieza al momento")],
    "de": [("Erst Abklingzeit,<br>dann kaufen", "Lieferdienst und Shopping erst nach der Abklingzeit"), ("In der Abklingzeit<br>kurz innehalten", "Wir zeigen dir, dass Brechen deine Einhaltung senkt"),
           ("So lange hast du<br>durchgehalten", "Einhaltung pro Eintrag und Verlauf auf einen Blick"), ("Von Reisen bis Lieferdienst<br>mit einem Tipp", "Häufige Abklingzeiten wählen und sofort starten")],
    "fr": [("La recharge d’abord,<br>l’achat ensuite", "Livraison et shopping attendent la fin de la recharge"), ("En recharge,<br>une pause de plus", "On vous prévient que rompre baisse votre respect"),
           ("Voyez combien de temps<br>vous avez tenu", "Respect par élément et historique en un coup d’œil"), ("Du voyage à la livraison<br>en un geste", "Choisissez une recharge courante et lancez-la")],
    "it": [("Prima la ricarica,<br>poi l’acquisto", "Consegne e shopping aspettano la fine della ricarica"), ("In ricarica,<br>fermati ancora", "Ti avvisiamo che romperla abbassa il tuo rispetto"),
           ("Guarda quanto<br>hai resistito", "Rispetto per elemento e cronologia a colpo d’occhio"), ("Dai viaggi alle consegne<br>con un tocco", "Scegli una ricarica comune e inizia subito")],
    "pt-BR": [("Primeiro a recarga,<br>depois a compra", "Delivery e compras esperam a recarga terminar"), ("Em recarga,<br>pare mais uma vez", "Avisamos que quebrar reduz seu cumprimento"),
              ("Veja quanto tempo<br>você aguentou", "Cumprimento por item e histórico de uso num relance"), ("De viagens a delivery<br>com um toque", "Escolha recargas comuns e comece na hora")],
    "th": [("คูลดาวน์ก่อน<br>แล้วค่อยซื้อ", "เดลิเวอรี่กับช้อปปิ้งต้องรอให้คูลดาวน์จบ"), ("ระหว่างคูลดาวน์<br>หยุดคิดอีกนิด", "เตือนว่าถ้าฝ่าฝืน การรักษาวินัยจะลดลง"),
           ("อดทนได้นานแค่ไหน<br>ดูเป็นตัวเลข", "การรักษาวินัยรายรายการและประวัติในที่เดียว"), ("ตั้งแต่เที่ยวถึงเดลิเวอรี่<br>เพิ่มได้ในแตะเดียว", "เลือกคูลดาวน์ที่ใช้บ่อยแล้วเริ่มได้ทันที")],
    "vi": [("Chờ trước,<br>mua sau", "Đồ ăn giao và mua sắm chờ hết thời gian chờ"), ("Đang chờ,<br>dừng lại thêm chút", "Nhắc bạn rằng phá thời gian chờ làm giảm tuân thủ"),
           ("Bạn đã kiềm chế<br>được bao lâu", "Tỷ lệ tuân thủ từng mục và lịch sử trong nháy mắt"), ("Từ du lịch đến đồ ăn giao<br>thêm bằng một chạm", "Chọn thời gian chờ quen thuộc và bắt đầu ngay")],
    "cs": [("Nejdřív čekací doba,<br>pak nákup", "Rozvoz i nákupy počkají na konec čekací doby"), ("V čekací době<br>se ještě zastav", "Upozorníme tě, že porušení sníží dodržování"),
           ("Kolik jsi<br>vydržel", "Dodržování podle položek a historie na první pohled"), ("Od cest po rozvoz<br>jedním klepnutím", "Vyber si běžnou čekací dobu a začni hned")],
    "da": [("Først ventetid,<br>så køb", "Levering og shopping venter, til ventetiden er slut"), ("I ventetid?<br>Tænk dig om igen", "Vi minder dig om, at et brud sænker din overholdelse"),
           ("Se hvor længe<br>du holdt ud", "Overholdelse pr. emne og historik på ét blik"), ("Fra rejser til levering<br>med ét tryk", "Vælg en almindelig ventetid og start med det samme")],
    "el": [("Πρώτα αναμονή,<br>μετά αγορά", "Delivery και ψώνια περιμένουν το τέλος της αναμονής"), ("Σε αναμονή;<br>Σκέψου το ξανά", "Σου θυμίζουμε ότι η παραβίαση μειώνει την τήρηση"),
           ("Δες πόσο<br>άντεξες", "Τήρηση ανά στοιχείο και ιστορικό με μια ματιά"), ("Από ταξίδια ως delivery<br>με ένα πάτημα", "Διάλεξε μια συνηθισμένη αναμονή και ξεκίνα αμέσως")],
    "fi": [("Ensin odotusaika,<br>sitten osto", "Kotiinkuljetus ja ostokset odottavat odotusajan loppua"), ("Odotusajalla?<br>Pysähdy vielä kerran", "Muistutamme, että rikkominen laskee noudattamista"),
           ("Näe kuinka kauan<br>kestit", "Noudattaminen kohteittain ja historia yhdellä silmäyksellä"), ("Matkoista ruokalähetyksiin<br>yhdellä napautuksella", "Valitse tuttu odotusaika ja aloita heti")],
    "id": [("Waktu jeda dulu,<br>baru beli", "Pesan antar dan belanja menunggu waktu jeda selesai"), ("Dalam waktu jeda?<br>Tahan sekali lagi", "Kami ingatkan, melanggar menurunkan kepatuhanmu"),
           ("Lihat berapa lama<br>kamu bertahan", "Kepatuhan per item dan riwayat dalam sekali lihat"), ("Dari liburan sampai pesan antar<br>sekali ketuk", "Pilih waktu jeda yang umum dan langsung mulai")],
    "nb": [("Først ventetid,<br>så kjøp", "Levering og shopping venter til ventetiden er over"), ("I ventetid?<br>Tenk deg om igjen", "Vi minner deg på at brudd senker etterlevelsen"),
           ("Se hvor lenge<br>du holdt ut", "Etterlevelse per element og historikk på et blikk"), ("Fra reiser til levering<br>med ett trykk", "Velg en vanlig ventetid og start med en gang")],
    "nl": [("Eerst wachttijd,<br>dan kopen", "Bezorging en winkelen wachten tot de wachttijd voorbij is"), ("In wachttijd?<br>Denk nog even na", "We waarschuwen dat doorbreken je naleving verlaagt"),
           ("Zie hoe lang<br>je volhield", "Naleving per item en geschiedenis in één oogopslag"), ("Van reizen tot bezorging<br>met één tik", "Kies een veelgebruikte wachttijd en begin meteen")],
    "pl": [("Najpierw czas oczekiwania,<br>potem zakup", "Dostawa i zakupy czekają do końca czasu oczekiwania"), ("W oczekiwaniu?<br>Zatrzymaj się jeszcze raz", "Przypomnimy, że złamanie obniża przestrzeganie"),
           ("Zobacz, jak długo<br>wytrzymałeś", "Przestrzeganie dla każdej pozycji i historia w jednym miejscu"), ("Od podróży po dostawy<br>jednym dotknięciem", "Wybierz popularny czas oczekiwania i zacznij od razu")],
    "sv": [("Först väntetid,<br>sedan köp", "Leverans och shopping väntar tills väntetiden är slut"), ("I väntetid?<br>Tänk efter en gång till", "Vi påminner om att ett brott sänker din följsamhet"),
           ("Se hur länge<br>du höll ut", "Följsamhet per objekt och historik i en överblick"), ("Från resor till leverans<br>med ett tryck", "Välj en vanlig väntetid och börja direkt")],
    "tr": [("Önce bekleme süresi,<br>sonra alışveriş", "Sipariş ve alışveriş, bekleme süresi bitince"), ("Bekleme süresinde<br>bir kez daha dur", "Bozarsan uyum oranının düşeceğini hatırlatırız"),
           ("Ne kadar<br>dayandığını gör", "Öğe bazında uyum ve kullanım geçmişi tek bakışta"), ("Seyahatten yemek siparişine<br>tek dokunuşla", "Sık kullanılan bir bekleme süresi seç ve hemen başla")],
}
STORE = {lang: lang for lang in TEXTS}   # 앱 언어 = App Store 로케일

FILES = [("01-home.png", "hero-bleed"), ("02-break.png", "left-text"), ("03-stats.png", "text-bottom"), ("04-templates.png", "dark")]
SHOTS = [(f, layout, {lang: TEXTS[lang][i] for lang in TEXTS}) for i, (f, layout) in enumerate(FILES)]

# 색은 헤더·검색 결과 그림(make_creative_assets.py)과 맞춘다.
THEME = dict(bg="#F2F2F7", ink="#16161A", sub="#76767E", dark_bg="#16161A", dark_ink="#ffffff",
             dark_sub="#9a9aa3", frame="#1b1b1f", rim="#c9c9d1", glow="rgba(46,204,112,.28)")

BASE_CSS = """
* { margin:0; padding:0; box-sizing:border-box; }
html,body { width:%(W)dpx; height:%(H)dpx; overflow:hidden; }
body { background:%(bg)s; font-family:"SF Pro Display", -apple-system, "Apple SD Gothic Neo", "Hiragino Sans", "PingFang SC", sans-serif; position:relative; }
.headline { font-size:96px; font-weight:800; color:%(ink)s; letter-spacing:-2px; line-height:1.22; text-wrap:balance; }
.sub { font-size:50px; font-weight:500; color:%(sub)s; letter-spacing:-1px; line-height:1.35; text-wrap:balance; }
:lang(ko) .headline, :lang(ko) .sub { word-break:keep-all; }
:lang(zh-Hant) { font-family:-apple-system, "PingFang TC", sans-serif; }
:lang(ja) { font-family:-apple-system, "Hiragino Sans", sans-serif; }
:lang(ja) .headline, :lang(ja) .sub, :lang(zh-Hans) .sub, :lang(zh-Hant) .sub { word-break:auto-phrase; }
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
# ⚠️ 글꼴은 "SF Pro Display" 를 먼저 쓴다. 헤드리스 Chrome 의 -apple-system 은 é · á · ñ 같은 글자를 다른 글꼴로 그려 어긋난다.
# 긴 언어(독일어 · 폴란드어 …)는 적은 줄(<br>) 수를 넘겨 쪼개지면 폰 그림과 겹친다 — 맞을 때까지 글을 줄인다.
FIT_JS = """<script>
function lines(el){ return Math.round(el.getBoundingClientRect().height / parseFloat(getComputedStyle(el).lineHeight)); }
function fit(el, want, min){ let size = parseFloat(getComputedStyle(el).fontSize);
  while (size > min && lines(el) > want) { size -= 2; el.style.fontSize = size + 'px'; } }
const h = document.querySelector('.headline'), s = document.querySelector('.sub');
fit(h, h.querySelectorAll('br').length + 1, 60); fit(s, 2, 34);
</script>"""
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
            page = HTML.format(lang=lang, css=css, body=tpl.format(h=h, s=s, img=src.as_uri()))
            html.write_text(page.replace("</body>", FIT_JS + "</body>"), encoding="utf-8")
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
