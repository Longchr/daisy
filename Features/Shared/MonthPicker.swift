import SwiftUI

struct MonthPicker: View {
    @Binding var month: Date

    private var title: String {
        month.formatted(.dateTime.year().month(.wide))
    }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("上个月")

            Text(title)
                .font(.subheadline.weight(.semibold))
                .contentTransition(.numericText())
                .frame(minWidth: 106)

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 32)
            }
            .disabled(Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month))
            .accessibilityLabel("下个月")
        }
        .buttonStyle(.plain)
        .foregroundStyle(DaisyTheme.accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.thinMaterial, in: Capsule())
    }

    private func changeMonth(by value: Int) {
        guard let changed = Calendar.current.date(byAdding: .month, value: value, to: month) else { return }
        withAnimation(.snappy) { month = changed }
    }
}
