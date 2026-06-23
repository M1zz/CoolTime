import SwiftUI

struct ToastView: View {
    let message: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
            Text(message)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(color)
                .shadow(color: color.opacity(0.3), radius: 8, y: 4)
        )
        // 토스트는 시각 요소이므로 VoiceOver 사용자에게 음성으로도 알린다.
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}
