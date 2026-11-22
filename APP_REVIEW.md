# 심사 대응 — Guideline 2.1(b) 인앱 구매를 찾을 수 없음

2026-11-10 심사, 1.0.4 (4), Submission ID `3834c616-9a0b-4136-be3c-7b748b4738be`.

## 원인

심사받은 1.0.4 (4) 빌드에는 페이월이 없다. 빌드 4 는 `178b1a1`(11월 6일 11:55)에서 만들었고,
요금제는 그 뒤 `983ada2`(같은 날 22:38)에 들어갔다. 상품 9개만 먼저 제출됐다.

⚠️ **새 빌드를 붙이기 전에 답장하지 않는다.** 빌드 4 로는 같은 리젝이 다시 온다.

## 순서

1. `main` 을 DeployBar 로 배포한다. App Store Connect 의 리젝된 1.0.4 는 버전 번호를 1.0.5 로 바꾼다
   (릴리즈노트가 1.0.5 로 써 있다). 빌드 번호는 5 이상 — `ProEntitlement.lastBuildBeforePaywall` 이 "4" 다.
2. TestFlight 에서 아래 메모의 3) · 4) 를 한 번 따라가 본다 (샌드박스 계정).
3. App Store Connect: 빌드를 새 것으로 바꾸고, 인앱 구매 9개가 이 제출에 그대로 들어 있는지 본다.
   유료 앱 계약(Paid Apps Agreement)이 활성인지도 확인한다.
4. 심사 메모는 배포가 `APPSTORE.md` 에서 올린다 (`--publish 쿨타임 --dry-run --text-only` 로 확인).
5. 아래 '답장' 을 보내고 다시 제출한다.

## 심사 메모 (App Review Information > Notes)

원본은 `APPSTORE.md` 의 `## 심사 메모` 절이다. DeployBar 가 배포할 때 메모 칸에 올리므로 손으로 넣지 않는다.

## 답장 (Resolution Center)

```
Hello,

Thank you for the review, and apologies for the confusion.

The build you reviewed, 1.0.4 (4), was uploaded before the purchase screen was
added, so the In-App Purchases could not be found in it. We have uploaded a new
build that contains the purchase screen and attached it to this submission.

In the new build, all In-App Purchases are on the "Plans" screen:
Home screen > gear icon (top left) > Settings > "CoolTime Plus · Pro".

- Plus card: Plus Yearly and Plus Lifetime; "See weekly and monthly" shows Plus Monthly and Plus Weekly.
- Pro card: Pro Yearly; "See weekly and monthly" shows Pro Monthly and Pro Weekly.
- Plus to Pro Lifetime: after buying Plus Lifetime, reopen Plans and choose "Lifetime" on the Pro card ("Upgrade to Pro Lifetime").
- CoolTime Pro Lifetime for Subs: while any subscription is active, Settings shows a "Switch to Lifetime" row.

There are no storefront or device restrictions. The same steps are in the App Review notes.

Thank you.
```

## 다음에 같은 리젝을 피하려면

- 인앱 구매를 제출할 때는 **그 상품을 파는 화면이 든 빌드**를 같이 붙인다. 빌드를 만든 커밋이 페이월 커밋 뒤인지 본다.
- 조건이 맞아야 보이는 상품(올리기 · 구독 졸업)은 심사 메모에 보이는 순서를 적는다.
