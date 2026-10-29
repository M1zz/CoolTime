// 쿨타임 웹 체험: 쓰면 쿨타임이 걸리고, 날이 지나면 원이 차오른다.
// 규칙은 앱과 같다. 준수율 = (사용 - 깬 횟수) / 사용 (CooldownItem.complianceRate), 전체는 쓴 아이템의 평균
// (CooldownManager.overallComplianceRate). 절반 알림·종료 알림은 NotificationManager 와 같은 때에 뜬다.
// 기다리는 시간만 '하루 지나기' 버튼으로 당긴다. 아이템 이름·주기는 앱의 추천 템플릿 그대로다.
(() => {
  const root = document.getElementById("demo");
  if (!root) return;
  const T = JSON.parse(root.dataset.text);
  const fmt = (s, ...v) => { let i = 0; return s.replace(/%(lld|@)/g, () => v[i++]); };

  let now = 0, cur = 0, warned = false, toastTimer;
  const items = T.items.map(it => ({ ...it, last: null, total: 0, broken: 0 }));
  const left = it => it.last === null ? 0 : Math.max(0, it.last + it.days - now);
  const onCooldown = it => left(it) > 0;
  const progress = it => it.last === null ? 1 : Math.min(1, (now - it.last) / it.days);

  root.innerHTML = `
    <div class="ct-stage">
      <div class="ct-circle" aria-hidden="true"><span class="ct-emoji"></span></div>
      <div class="ct-name"></div>
      <div class="ct-state" aria-live="polite"></div>
      <div class="ct-toast" role="status"></div>
    </div>
    <div class="ct-controls">
      <div class="ct-items" role="group">
        ${items.map((it, i) => `<button type="button" class="chip" data-item="${i}" aria-pressed="false">${it.emoji} <span></span></button>`).join("")}
      </div>
      <div class="ct-actions">
        <button type="button" class="ct-main"></button>
        <button type="button" class="ct-day">${T.nextDay}</button>
      </div>
      <div class="ct-warn" hidden>
        <strong>⚠️ ${T.warnTitle}</strong>
        <p>${T.warnText}</p>
        <button type="button" class="ct-break">${T.breakIt}</button>
      </div>
      <dl class="ct-stats">
        <div><dt>${T.compliance}</dt><dd class="ct-rate"></dd></div>
        <div><dt>${T.total}</dt><dd class="ct-total"></dd></div>
        <div><dt>${T.breaks}</dt><dd class="ct-broken"></dd></div>
      </dl>
      <p class="muted small">${T.note}</p>
    </div>`;

  const $ = s => root.querySelector(s);
  const circle = $(".ct-circle"), main = $(".ct-main"), warn = $(".ct-warn"), toast = $(".ct-toast");
  root.querySelectorAll("[data-item] span").forEach((s, i) => { s.textContent = items[i].name; });

  function render() {
    const it = items[cur], cool = onCooldown(it);
    $(".ct-emoji").textContent = it.emoji;
    $(".ct-name").textContent = it.name;
    $(".ct-state").textContent = cool ? fmt(T.left, fmt(T.dh, left(it), 0)) : `${T.ready} · ${it.every}`;
    circle.classList.toggle("ready", !cool);
    circle.style.setProperty("--p", progress(it));
    main.textContent = cool ? T.breakShort : T.use;
    main.classList.toggle("break", cool);
    main.classList.toggle("hint", !root.dataset.used);
    warn.hidden = !(cool && warned);
    root.querySelectorAll("[data-item]").forEach((b, i) => b.setAttribute("aria-pressed", i === cur));
    const used = items.filter(x => x.total > 0);
    const rate = used.length ? used.reduce((a, x) => a + (x.total - x.broken) / x.total, 0) / used.length : 1;
    $(".ct-rate").textContent = `${Math.round(rate * 100)}%`;
    $(".ct-total").textContent = items.reduce((a, x) => a + x.total, 0);
    $(".ct-broken").textContent = items.reduce((a, x) => a + x.broken, 0);
  }

  function say(text) {
    toast.textContent = text;
    toast.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove("show"), 2200);
  }

  // 앱의 CooldownItem.use 와 같다. 쿨타임 중에 쓰면 깬 횟수가 하나 는다.
  function use(brokeRule) {
    const it = items[cur];
    it.total += 1;
    if (brokeRule) it.broken += 1;
    it.last = now;
    warned = false;
    root.dataset.used = "1";
    circle.classList.remove("bump"); void circle.offsetWidth; circle.classList.add("bump");
    render();
  }

  main.addEventListener("click", () => {
    if (onCooldown(items[cur])) { warned = true; render(); $(".ct-break").focus(); }
    else use(false);
  });
  $(".ct-break").addEventListener("click", () => use(true));
  $(".ct-day").addEventListener("click", () => {
    const before = now;
    now += 1;
    warned = false;
    // 하루 사이에 절반·끝을 지난 아이템이 있으면 앱처럼 알린다.
    for (const it of items) {
      if (it.last === null) continue;
      const half = it.last + it.days / 2, end = it.last + it.days;
      if (before < end && now >= end) say(fmt(T.end, it.emoji));
      else if (before < half && now >= half) say(fmt(T.half, it.emoji));
    }
    render();
  });
  root.addEventListener("click", e => {
    const b = e.target.closest("[data-item]");
    if (b) { cur = +b.dataset.item; warned = false; render(); }
  });

  render();
})();
