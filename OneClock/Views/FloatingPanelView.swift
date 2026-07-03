import SwiftUI

struct FloatingPanelView: View {
    var onClose: @MainActor () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("One Clock")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Complete the floating panel lifecycle spike")
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
            }

            Text("25:00")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)

            ProgressView(value: 0.18)
                .progressViewStyle(.linear)
                .tint(.blue)

            Text("Technical spike placeholder")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(24)
        .frame(width: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.28), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            Button("Hide One Clock", systemImage: "xmark.circle.fill", action: onClose)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(14)
                .accessibilityLabel("Hide One Clock")
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    FloatingPanelView()
        .padding()
}
