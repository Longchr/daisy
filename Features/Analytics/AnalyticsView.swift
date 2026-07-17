import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \LedgerTransaction.occurredAt, order: .reverse) private var transactions: [LedgerTransaction]
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]

    private var monthly: [LedgerTransaction] {
        transactions.filter { Calendar.current.isDate($0.occurredAt, equalTo: appState.selectedMonth, toGranularity: .month) }
    }

    private var categoryMap: [String: LedgerCategory] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    private var categoryTotals: [CategoryTotal] {
        let expenses = monthly.filter { $0.kind == .expense }
        let grouped = Dictionary(grouping: expenses, by: \.categoryID)
        return grouped.map { id, values in
            let category = categoryMap[id]
            return CategoryTotal(
                id: id,
                name: category?.name ?? "其他",
                symbol: category?.symbol ?? "ellipsis.circle.fill",
                tint: Color(hex: category?.tintHex ?? "8A8A8E"),
                amountMinor: values.reduce(0) { $0 + $1.amountMinor }
            )
        }.sorted { $0.amountMinor > $1.amountMinor }
    }

    private var expenseMinor: Int64 { categoryTotals.reduce(0) { $0 + $1.amountMinor } }
    private var incomeMinor: Int64 {
        monthly.filter { $0.kind == .income || $0.kind == .refund }.reduce(0) { $0 + $1.amountMinor }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    HStack {
                        MonthPicker(month: $appState.selectedMonth)
                        Spacer()
                    }

                    insightSummary
                    categoryChart
                    categoryRanking
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(DaisyTheme.pageGradient.ignoresSafeArea())
            .navigationTitle("分析")
        }
    }

    private var insightSummary: some View {
        HStack(spacing: 12) {
            MiniMetricCard(
                title: "本月支出",
                value: settings.hideAmounts ? "••••" : Money(minorUnits: expenseMinor).formatted(),
                symbol: "arrow.up.right",
                tint: DaisyTheme.expense
            )
            MiniMetricCard(
                title: "储蓄率",
                value: settings.hideAmounts ? "••%" : savingsRate.formatted(.percent.precision(.fractionLength(0))),
                symbol: "leaf.fill",
                tint: DaisyTheme.income
            )
        }
    }

    private var savingsRate: Double {
        guard incomeMinor > 0 else { return 0 }
        return max(-1, min(1, Double(incomeMinor - expenseMinor) / Double(incomeMinor)))
    }

    private var categoryChart: some View {
        DaisyCard {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("钱花在了哪里")
                        .font(.headline)
                    Text("本月分类占比")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if categoryTotals.isEmpty {
                    ContentUnavailableView("暂无可分析数据", systemImage: "chart.pie", description: Text("支出账单会自动汇总到这里。"))
                        .frame(height: 220)
                } else {
                    ZStack {
                        Chart(categoryTotals.prefix(7)) { item in
                            SectorMark(
                                angle: .value("金额", item.amountMinor),
                                innerRadius: .ratio(0.66),
                                angularInset: 2.2
                            )
                            .cornerRadius(5)
                            .foregroundStyle(item.tint)
                        }
                        .frame(height: 230)

                        VStack(spacing: 3) {
                            Text("总支出")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(settings.hideAmounts ? "••••" : Money(minorUnits: expenseMinor).formatted())
                                .font(.headline.monospacedDigit())
                        }
                    }
                    .accessibilityLabel("本月分类支出占比")
                }
            }
        }
    }

    private var categoryRanking: some View {
        DaisyCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("分类排行")
                    .font(.headline)

                if categoryTotals.isEmpty {
                    Text("暂无排行")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    ForEach(Array(categoryTotals.prefix(6).enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            CategoryIcon(symbol: item.symbol, tint: item.tint, size: 40)
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(item.name)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text(settings.hideAmounts ? "••••" : Money(minorUnits: item.amountMinor).formatted())
                                        .font(.subheadline.monospacedDigit().weight(.semibold))
                                }
                                ProgressView(value: expenseMinor == 0 ? 0 : Double(item.amountMinor) / Double(expenseMinor))
                                    .tint(item.tint)
                            }
                        }
                        if index < min(6, categoryTotals.count) - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
            }
        }
    }
}

private struct CategoryTotal: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let tint: Color
    let amountMinor: Int64
}

private struct MiniMetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        DaisyCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
    }
}

#Preview {
    AnalyticsView()
        .environmentObject(AppState())
        .environmentObject(AppSettings.shared)
        .modelContainer(AppDatabase.preview.container)
}
