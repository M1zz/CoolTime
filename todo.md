# CoolTime 할 일 목록

## 완료된 작업 ✅

- [x] 구독 모델 → 평생 이용권으로 전환 (₩7,900 → $5.99 USD, Non-Consumable)
- [x] 무료 아이템 상한 5개 → 3개로 변경
- [x] PurchaseManager 완전 재작성 (StoreKit 2, `com.cooltime.pro.lifetime`)
- [x] PaywallView 재작성 (단일 평생권 카드, 가격 $5.99 표시)
- [x] CoolTime.storekit 업데이트 (Non-Consumable, $5.99 USD)
- [x] 영어 로컬라이제이션 구현 (en.lproj/Localizable.strings)
- [x] 한국어 포맷 스트링 정렬 (ko.lproj/Localizable.strings)
- [x] pbxproj에 Localizable.strings PBXVariantGroup 추가
- [x] TemplatesView 색상/가독성 개선 (Settings 스타일 목록)
- [x] StatsView 페이월 버튼 연결 (잠금 오버레이 → sheet)
- [x] 위젯 재설계: CoolTimeWidget / ResistanceWidget / CoolTimeAccessoryWidget
- [x] 위젯 타임라인 효율화 (60개 항목 → 단일 항목 + 스마트 갱신)
- [x] CooldownManager.syncWidgetData()에 estimatedCost 포함 확인

## 남은 작업 ⏳

- [ ] **App Store Connect**: `com.cooltime.pro.lifetime` Non-Consumable 상품 생성 (Tier 6, $5.99)
- [ ] **App Store Connect**: 기존 구독 상품 비활성화
- [ ] **Xcode 확인**: App Group `group.com.Ysoup.CoolTime.shared` 양쪽 타겟에 설정됐는지 확인
- [ ] **Xcode 빌드**: widgetExtension 타겟 컴파일 에러 없는지 확인 (@main 충돌 여부)
- [ ] **실기기 테스트**: 위젯 표시 및 갱신 동작 확인
- [ ] **실기기 테스트**: 평생 이용권 구매 플로우 Sandbox 테스트
