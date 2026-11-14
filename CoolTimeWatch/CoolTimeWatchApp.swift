//
//  CoolTimeWatchApp.swift
//  손목의 쿨타임: 사고 싶은 마음이 올라온 그 자리에서 폰을 꺼내지 않고 "아직이야?" 를 본다.
//  폰을 꺼내면 쇼핑 앱이 한 번 더 손에 닿는다 — 손목에서 답을 보고 끝내는 것이 이 앱의 일이다.
//  끝나는 순간의 알림은 아이폰 알림이 손목으로 그대로 넘어온다(따로 걸지 않는다).
//

import SwiftUI

@main
struct CoolTimeWatchApp: App {
    @StateObject private var link = WatchLink.shared

    var body: some Scene {
        WindowGroup {
            CooldownList()
                .environmentObject(link)
                .task { link.activate() }
        }
    }
}

struct CooldownList: View {
    @EnvironmentObject private var link: WatchLink
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) { list }
        #if DEBUG
            // 스크린샷: `-watchDemoOpen YES` 면 첫 항목을 열어 둔다
            .task {
                if UserDefaults.standard.bool(forKey: "watchDemoOpen"), let first = link.snapshot?.sorted.first {
                    path = [first.id]
                }
            }
        #endif
    }

    private var list: some View {
        Group {
            if let items = link.snapshot?.sorted, !items.isEmpty {
                List(items) { item in
                    NavigationLink(value: item.id) { CooldownRow(item: item) }
                }
                .navigationDestination(for: UUID.self) { id in
                    if let item = link.snapshot?.items.first(where: { $0.id == id }) {
                        CooldownDetail(item: item)
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("쿨타임", systemImage: "hourglass")
                } description: {
                    Text("iPhone에서 쿨타임을 걸면 여기에 떠요")
                }
            }
        }
        .navigationTitle("쿨타임")
    }
}

/// 한 줄: 이모지 · 이름 · 남은 시간(시스템이 세는 글자라 매초 다시 그리지 않아도 줄어든다)
struct CooldownRow: View {
    let item: WatchCooldown

    var body: some View {
        HStack(spacing: 8) {
            Text(item.emoji).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).lineLimit(1)
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    if let end = item.endsAt, end > context.date {
                        item.remaining(at: context.date)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.orange)
                    } else {
                        Text("지금 써도 돼요").font(.caption).foregroundStyle(.green)
                    }
                }
            }
        }
    }
}

/// 한 항목: 큰 링 + [썼어요]. 쿨타임 중이면 한 번 묻는다 — 깨는 것도 기록이다.
struct CooldownDetail: View {
    @EnvironmentObject private var link: WatchLink
    let item: WatchCooldown
    @State private var confirmBreak = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let cooling = item.isCooling(at: context.date)
            VStack(spacing: 8) {
                ZStack {
                    Circle().stroke(.quaternary, lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: progress(at: context.date))
                        .stroke(cooling ? Color.orange : Color.green, style: .init(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(item.emoji).font(.title2)
                        if cooling {
                            item.remaining(at: context.date)
                                .font(.caption.monospacedDigit())
                                .multilineTextAlignment(.center)
                                .lineLimit(1).minimumScaleFactor(0.6)
                                .padding(.horizontal, 14)
                        } else {
                            Text("지금 써도 돼요").font(.caption2).foregroundStyle(.green)
                        }
                    }
                }
                .frame(maxHeight: 96)
                Button("썼어요") {
                    if cooling { confirmBreak = true } else { link.use(item) }
                }
                .tint(cooling ? .orange : .green)
            }
            .confirmationDialog("아직 쿨타임 중이에요. 그래도 남길까요?", isPresented: $confirmBreak) {
                Button("남기기", role: .destructive) { link.use(item) }
                Button("참을게요", role: .cancel) {}
            }
        }
        .navigationTitle(item.name)
    }

    private func progress(at date: Date) -> CGFloat {
        guard let last = item.lastUsed, item.duration > 0 else { return 1 }
        return min(1, max(0, date.timeIntervalSince(last) / item.duration))
    }
}
