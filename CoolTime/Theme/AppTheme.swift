//
//  AppTheme.swift
//  CoolTime
//
//  앱 전체 테마 색상 시스템
//

import SwiftUI

/// 앱 테마 색상
enum AppTheme {
    // MARK: - Primary Colors

    /// 사용 가능/성공 (에메랄드 그린)
    static let ready = Color(red: 0.18, green: 0.8, blue: 0.44)

    /// 쿨타임 중 (생생한 블루)
    static let cooldown = Color(red: 0.35, green: 0.55, blue: 1.0)

    /// 쿨타임 프로그레스 (퍼플)
    static let cooldownAccent = Color(red: 0.7, green: 0.4, blue: 1.0)

    /// 경고/쿨타임 깨기 (오렌지)
    static let warning = Color(red: 1.0, green: 0.55, blue: 0.2)

    /// 위험/에러 (레드)
    static let danger = Color(red: 1.0, green: 0.35, blue: 0.35)

    // MARK: - Gradients

    /// 사용 가능 그라데이션
    static let readyGradient = LinearGradient(
        colors: [ready, Color(red: 0.0, green: 0.85, blue: 0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 쿨타임 그라데이션
    static let cooldownGradient = LinearGradient(
        colors: [cooldown, cooldownAccent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 경고 그라데이션
    static let warningGradient = LinearGradient(
        colors: [warning, Color(red: 1.0, green: 0.4, blue: 0.3)],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - High-Contrast Solid Colors (저시력 대응)

    /// 사용 가능 (라이트에서 충분한 대비를 위해 톤 다운한 진한 그린)
    static let readyStrong = Color(red: 0.0, green: 0.55, blue: 0.30)

    /// 기다리는 중 (진한 블루)
    static let waitingStrong = Color(red: 0.10, green: 0.35, blue: 0.85)

    // MARK: - Status (단일 소스 of truth)

    /// 아이템 상태를 (텍스트, SF심볼, 색)으로 표현 — 행/시트/위젯이 모두 공유
    /// 색에만 의존하지 않도록 항상 텍스트 + 심볼을 함께 노출한다.
    struct StatusStyle {
        let text: LocalizedStringKey
        let symbol: String
        let color: Color
    }

    static func status(isOnCooldown: Bool, remainingText: String) -> StatusStyle {
        if isOnCooldown {
            // "내가 이걸 한 지 얼마 안 됐네 = 아직" 을 가장 단순하게 전달
            return StatusStyle(text: "아직이에요", symbol: "hourglass", color: waitingStrong)
        } else {
            return StatusStyle(text: "사용 가능", symbol: "checkmark.circle.fill", color: readyStrong)
        }
    }

    // MARK: - Semantic Colors

    /// 준수율 색상
    static func complianceColor(for rate: Double) -> Color {
        if rate >= 0.8 { return readyStrong }
        if rate >= 0.5 { return warning }
        return danger
    }

    // MARK: - Background Colors

    /// 카드 배경 (다크/라이트 모드 대응)
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(white: 0.12)
            : Color.white
    }

    /// 페이지 배경
    static func pageBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(white: 0.05)
            : Color(red: 0.95, green: 0.95, blue: 0.97)
    }

    /// 원형 배경
    static func circleBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(white: 0.15)
            : Color(red: 0.92, green: 0.92, blue: 0.94)
    }

    /// 오버레이 색상
    static func overlayColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color.black.opacity(0.55)
            : Color(red: 0.3, green: 0.3, blue: 0.4).opacity(0.35)
    }

    // MARK: - Border & Shadow

    /// 테두리 색상
    static func borderColor(for colorScheme: ColorScheme, isActive: Bool = false, activeColor: Color = ready) -> Color {
        if isActive {
            return activeColor.opacity(0.5)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.1)
            : Color.gray.opacity(0.15)
    }

    /// 그림자 색상
    static func shadowColor(for colorScheme: ColorScheme, isActive: Bool = false, activeColor: Color = ready) -> Color {
        if isActive {
            return activeColor.opacity(colorScheme == .dark ? 0.3 : 0.25)
        }
        return Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08)
    }
}

// MARK: - View Extensions

extension View {
    /// 앱 테마 카드 스타일
    func appCardStyle(
        colorScheme: ColorScheme,
        isActive: Bool = false,
        activeColor: Color = AppTheme.ready
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(AppTheme.cardBackground(for: colorScheme))
                    .shadow(
                        color: AppTheme.shadowColor(for: colorScheme, isActive: isActive, activeColor: activeColor),
                        radius: isActive ? 12 : 8,
                        y: 4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        AppTheme.borderColor(for: colorScheme, isActive: isActive, activeColor: activeColor),
                        lineWidth: isActive ? 2 : 1
                    )
            )
    }

    /// 앱 테마 버튼 스타일
    func appButtonStyle(color: Color = AppTheme.ready) -> some View {
        self
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(color)
            )
    }

    /// 앱 테마 그라데이션 버튼 스타일
    func appGradientButtonStyle(gradient: LinearGradient = AppTheme.readyGradient) -> some View {
        self
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(gradient)
            )
    }
}

// MARK: - Haptics

/// 앱 전역 햅틱 헬퍼
enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Pressable Button Style

/// 누르면 살짝 작아지는 타일 버튼 스타일 (Reduce Motion이면 정적)
struct PressableTileStyle: ButtonStyle {
    var reduceMotion: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6),
                       value: configuration.isPressed)
    }
}
