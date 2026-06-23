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

## 진행 중: 전면 리디자인 (시각장애인 친화 · 인지 최소화) 🔄

방향: 최대 단순화 · 단일 화면 · 사용/깨기 통합 · 고대비/큰글씨
계획: ~/.claude/plans/cuddly-munching-eich.md

- [x] AppTheme: status(isOnCooldown:) 단일 헬퍼 + 고대비 솔리드 색(readyStrong/waitingStrong)
- [x] CooldownManager: readyItems / waitingItems 정렬 헬퍼
- [x] CooldownRow 신규: 통일된 List 행 (상태 먼저 읽는 a11y 라벨 + 진행 표시)
- [x] HomeView 재작성: 2섹션, confirmationDialog 통합 액션, 캐러셀/검색/지표카드 제거
- [x] 홈을 그리드로 변경: CooldownTile(카드) + LazyVGrid, 스와이프 대신 컨텍스트 메뉴(삭제/리셋)
- [x] 그리드 고정 2열 + 게임 스킬 쿨타임 아이콘: 사용가능=밝게+발광, 쿨타임 중=어두운 베이스에서 시계방향으로 밝게 차오름(ActivationWedge, Shape 보간) + 남은시간 크게(compactCooldownFormatted)
- [x] 애니메이션: 와이프 부드러운 보간(linear 1s), 사용가능 전환/사용/삭제 시 스프링 재배치, 누름 스케일(PressableTileStyle), Reduce Motion 모두 존중
- [x] 햅틱(Haptics 헬퍼): 탭=light, 했어요=success/깸=warning, 삭제=medium, 리셋=rigid, 쿨타임 완료=success notify
- [x] HomeView 1초 ticker로 카운트다운/와이프 실시간 갱신 + 사용가능 전환 감지
- [x] 대기 상태 문구 "아직이에요"(Not yet)로 단순화 — "할 수 있나? 아직" 즉답, 정확한 시간은 아이콘 숫자+VoiceOver
- [x] 상단 툴바 제거 → 하단 바(기록/추가)로 이동, "쿨타임" 제목 텍스트 제거(.toolbar hidden)
- [x] 최대 단순화 + 모든 요소에 단일 의미 부여: 글로우(장식) 제거, 테두리 이중화 제거(아이콘 1곳만 상태색·카드는 중립 헤어라인), 빈 화면 버튼 중복 제거(하단 추가로 일원화). 통일 은유=충전(다 쓰면 꺼짐→시계방향 차오름→다 차면 켜짐)
- [x] 섹션 헤더(지금 할 수 있어요/기다리는 중) 제거 → 단일 그리드(사용가능→대기 정렬). 타일 모양이 상태를 말하므로 헤더 불필요
- [x] 기록(StatsView) 단순화: 차트/준수율/카테고리/블러잠금 제거 → 항목별 한 줄(이모지·이름·마지막·N번) + Pro 전체내역 업셀. 심판 빼고 거울(횟수·마지막)만
- [x] 개발 빌드 Pro 자동 활성화: PurchaseManager #if DEBUG → isPro=true (StoreKit 미호출). RELEASE는 실제 결제 유지, TestFlight 자동 Pro 유지

## 전략 전환: 충동구매 절제 × 선제 개입 🎯

- [x] (a) 위젯 전면 재설계 = 선제 개입 도구: 준수율/저항/보호중/주의(심판) 제거 → "아직이에요 + 지금 사면 ₩X + 이번 달 ₩X 아꼈어요". 잠금화면(rect/circular/inline)이 지를 때 먼저 말려주는 핵심. 충전 링 은유 통일
- [x] (b) 충동구매 절제 버티컬:
  - 온보딩 카피 → "또 지르고 후회했나요?" 배달·쇼핑·구독 + 절약 프레이밍(💸/✋)
  - 기록 상단에 "이번 달 아낀 돈" 후크(획득용 hard ROI)
  - 템플릿은 이미 충동소비 중심(배달/카페/쇼핑/술/구독 등) 활용
- [x] ① 위젯 Pro 잠금 제거 (위젯=무료 후크). WidgetLockView/isUnlocked 삭제
- [x] ② 스트릭 "N일째 충동 없이": CooldownManager.streakDays + WidgetStats.streakDays(앱·위젯 동기), 기록 화면 + 위젯(savedView·잠금화면)에 표시
- [ ] ③ 능동 개입 — 설계안 작성됨(ACTIVE_INTERVENTION_DESIGN.md). 구현 대기
- [x] 항목 수정 기능: 타일 길게누르기 → 수정 → AddItemView 편집모드(이름/주기/아이콘/비용 프리필 후 저장). 삭제/리셋은 같은 메뉴에 유지
- [x] 위젯 빈 화면 진단: WidgetStats.lastSync 추가 → "앱그룹 미연결"(못 읽음) vs "동기화됨·항목 0"(데이터 문제) 구분 표시
- [ ] (실기기) 위젯 진단 결과 확인 → App Group 위젯 타겟 포털 등록 점검
- [x] PurchaseManager: appStoreReceiptURL(iOS18 deprecated) → AppTransaction.shared, 경고 0개. DEBUG 스크린샷모드(-SeedSampleData)는 StoreKit 호출 스킵
- [x] ToastView: VoiceOver announce 동반
- [x] CooldownCircle: Reduce Motion 가드
- [x] AddItemView 단순화: 이름 + 프리셋 주기, 카테고리 제거, 템플릿 흡수
- [x] OnboardingView 2페이지로 축소 + Reduce Motion
- [x] StatsView 접근성 라벨/간소화 (준수율 링/차트/StatItem 음성화)
- [x] Localizable.strings (ko/en) 신규 키
- [x] 빌드 성공 (iPhone 17 시뮬레이터, Debug)
- [ ] 시뮬레이터 실행 + 화면 확인
- [ ] (선택) 미사용 파일 정리: ItemCard / ItemCardCompact / UseItemSheet / CooldownRow(그리드 전환으로 미사용) — 현재 빌드엔 무해(컴파일됨)
- [ ] (선택) DEBUG 전용 샘플 시드(`-SeedSampleData`, CooldownManager) 유지/제거 결정 — 릴리스 빌드엔 미포함
- [ ] (실기기) VoiceOver/Dynamic Type/Reduce Motion 수동 검증

## 남은 작업 ⏳

- [ ] **App Store Connect**: `com.cooltime.pro.lifetime` Non-Consumable 상품 생성 (Tier 6, $5.99)
- [ ] **App Store Connect**: 기존 구독 상품 비활성화
- [x] **App Group 설정 완료**: entitlements 파일 2개 생성 + 4개 빌드설정에 CODE_SIGN_ENTITLEMENTS 연결. 공유 저장소에 widget_stats/items 기록 검증됨(isPro=true, 절약 305000)
- [x] 위젯 DEBUG 잠금 해제(isUnlocked) — 개발 빌드에서 항상 Pro
- [ ] **Xcode 빌드**: widgetExtension 타겟 컴파일 에러 없는지 확인 (@main 충돌 여부)
- [ ] **실기기 테스트**: 위젯 표시 및 갱신 동작 확인
- [ ] **실기기 테스트**: 평생 이용권 구매 플로우 Sandbox 테스트
