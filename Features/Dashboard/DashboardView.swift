import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \LedgerTransaction.occurredAt, order: .reverse) private var transactions: [LedgerTransaction]
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]
    @Query(sort: \MonthlyBudget.monthStart, order: .reverse) private var budgets: [MonthlyBudget]

    private var monthlyTransactions: [LedgerTransaction] {
        transactions.filter { Calendar.current.isDate($0.occurredAt, equalTo: appState.selectedMonth, toGranularity: .month) }
    }

    private var expenseMinor: Int64 {
        monthlyTransactions.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountMinor }
    }

    private var incomeMinor: Int64 {
        monthlyTransactions.filter { $0.kind == .income || $0.kind == .refund }.reduce(0) { $0 + $1.amountMinor }
    }

    private var balanceMinor: Int64 { incomeMinor - expenseMinor }

    private var categoryMap: [String: LedgerCategory] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
    }

    private var currentBudget: MonthlyBudget? {
        budgets.first {
            $0.categoryID == nil && Calendar.current.isDate($0.monthStart, equalTo: appState.selectedMonth, toGranularity: .month)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    HStack {
                        MonthPicker(month: $appState.selectedMonth)
                        Spacer()
                        Button {
                            withAnimation(.snappy) { settings.hideAmounts.toggle() }
                        } label: {
                            Image(systemName: settings.hideAmounts ? "eye.slash.fill" : "eye.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 36, height: 36)
                                .background(.thinMaterial, in: Circle())
                        }
                        .accessibilityLabel(settings.hideAmounts ? "显示金额" : "隐藏金额")
                    }

                    BalanceHeroCard(
                        expenseMinor: expenseMinor,
                        incomeMinor: incomeMinor,
                        balanceMinor: balanceMinor,
                        hideAmounts: settings.hideAmounts
                    )

                    BudgetProgressCard(budget: currentBudget, spentMinor: expenseMinor, hideAmounts: settings.hideAmounts) {
                        appState.showBudgetSettings(for: appState.selectedMonth)
                    }

                    SpendingTrendCard(transactions: monthlyTransactions) { date in
                        appState.showTransactions(.day(date))
                    }

                    RecentTransactionsCard(
                        transactions: Array(monthlyTransactions.prefix(5)),
                        categoryMap: categoryMap,
                        hideAmounts: settings.hideAmounts
                    ) {
                        appState.showTransactions(.month(appState.selectedMonth))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .background(DaisyTheme.pageGradient.ignoresSafeArea())
            .navigationTitle("Daisy")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            appState.isPresentingAddTransaction = true
                        } label: {
                            Label("手动记账", systemImage: "square.and.pencil")
                        }
                        Button {
                            appState.isPresentingRecognitionImport = true
                        } label: {
                            Label("识别付款截图", systemImage: "viewfinder")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                    .accessibilityIdentifier("addTransactionButton")
                    .accessibilityLabel("记一笔")
                }
            }
        }
    }
}

private struct BudgetProgressCard: View {
    let budget: MonthlyBudget?
    let spentMinor: Int64
    let hideAmounts: Bool
    let configure: () -> Void

    private var progress: Double {
        guard let amount = budget?.amountMinor, amount > 0 else { return 0 }
        return min(1, Double(spentMinor) / Double(amount))
    }

    var body: some View {
        Button(action: configure) {
            DaisyCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("月度预算")
                                .font(.headline)
                            if let budget {
                                let remaining = max(0, budget.amountMinor - spentMinor)
                                Text(hideAmounts ? "剩余 ••••" : "剩余 \(Money(minorUnits: remaining).formatted())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("设置一个舒适的消费边界")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if budget != nil {
                            Text(progress.formatted(.percent.precision(.fractionLength(0))))
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(progress >= 1 ? DaisyTheme.danger : DaisyTheme.accent)
                        } else {
                            Text("设置")
                                .font(.subheadline.weight(.semibold))
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }

                    ProgressView(value: progress)
                        .tint(progress >= 1 ? DaisyTheme.danger : progress > 0.8 ? DaisyTheme.warning : DaisyTheme.accent)
                        .scaleEffect(y: 1.7)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dashboardBudgetCard")
        .accessibilityHint("打开月度预算设置")
    }
}

private struct BalanceHeroCard: View {
    let expenseMinor: Int64
    let incomeMinor: Int64
    let balanceMinor: Int64
    let hideAmounts: Bool

    private func rendered(_ value: Int64) -> String {
        hideAmounts ? "••••••" : Money(minorUnits: value).formatted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("本月结余")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
                Text(rendered(balanceMinor))
                    .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.75)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("monthlyBalance")
            }

            HStack(spacing: 0) {
                SummaryMetric(title: "支出", value: rendered(expenseMinor), symbol: "arrow.up.right", tint: Color.white.opacity(0.92))
                Divider().overlay(.white.opacity(0.22)).padding(.horizontal, 18)
                SummaryMetric(title: "收入", value: rendered(incomeMinor), symbol: "arrow.down.left", tint: Color.white.opacity(0.92))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [DaisyTheme.navy, DaisyTheme.accent.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "camera.macro")
                        .font(.system(size: 112, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.07))
                        .offset(x: 18, y: -12)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: DaisyTheme.navy.opacity(0.22), radius: 20, y: 11)
    }
}

private struct SummaryMetric: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.68))
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DailySpending: Identifiable {
    let date: Date
    let amountMinor: Int64
    var id: Date { date }
}

private struct SpendingTrendCard: View {
    let transactions: [LedgerTransaction]
    let showTransactions: (Date) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedDate: Date?

    private var points: [DailySpending] {
        let expenses = transactions.filter { $0.kind == .expense }
        let grouped = Dictionary(grouping: expenses) { Calendar.current.startOfDay(for: $0.occurredAt) }
        return grouped.map { date, values in
            DailySpending(date: date, amountMinor: values.reduce(0) { $0 + $1.amountMinor })
        }.sorted { $0.date < $1.date }
    }

    private var selectedPoint: DailySpending? {
        guard let selectedDate else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    var body: some View {
        DaisyCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("支出趋势")
                            .font(.headline)
                        Text("按日查看本月消费节奏")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(DaisyTheme.accent)
                }

                if points.isEmpty {
                    ContentUnavailableView("暂无支出", systemImage: "chart.xyaxis.line", description: Text("记下第一笔账后，这里会出现趋势。"))
                        .frame(height: 150)
                } else {
                    Chart(points) { point in
                        AreaMark(
                            x: .value("日期", point.date, unit: .day),
                            y: .value("支出", Double(point.amountMinor) / 100)
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [DaisyTheme.accent.opacity(0.34), DaisyTheme.accent.opacity(0.02)], startPoint: .top, endPoint: .bottom)
                        )
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("日期", point.date, unit: .day),
                            y: .value("支出", Double(point.amountMinor) / 100)
                        )
                        .foregroundStyle(DaisyTheme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)

                        if selectedPoint?.id == point.id {
                            RuleMark(x: .value("选中日期", point.date, unit: .day))
                                .foregroundStyle(DaisyTheme.accent.opacity(0.35))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            PointMark(
                                x: .value("选中日期", point.date, unit: .day),
                                y: .value("选中支出", Double(point.amountMinor) / 100)
                            )
                            .foregroundStyle(DaisyTheme.accent)
                            .symbolSize(55)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { value in
                            AxisValueLabel(format: .dateTime.day())
                            AxisGridLine().foregroundStyle(.primary.opacity(0.04))
                        }
                    }
                    .chartYAxis(.hidden)
                    .chartXSelection(value: $selectedDate)
                    .frame(height: 160)
                    .accessibilityIdentifier("spendingTrendChart")
                    .accessibilityLabel("本月支出趋势图，可选择日期查看账单")

                    if let selectedPoint {
                        Button {
                            showTransactions(selectedPoint.date)
                        } label: {
                            HStack(spacing: 10) {
                                Label(
                                    selectedPoint.date.formatted(.dateTime.month().day().weekday(.abbreviated)),
                                    systemImage: "calendar"
                                )
                                .font(.subheadline.weight(.medium))
                                Spacer()
                                Text(Money(minorUnits: selectedPoint.amountMinor).formatted())
                                    .font(.subheadline.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(DaisyTheme.expense)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .frame(minHeight: 44)
                        .accessibilityHint("查看当天账单")
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: selectedPoint?.id)
    }
}

private struct RecentTransactionsCard: View {
    let transactions: [LedgerTransaction]
    let categoryMap: [String: LedgerCategory]
    let hideAmounts: Bool
    let showAll: () -> Void

    var body: some View {
        DaisyCard {
            VStack(spacing: 4) {
                HStack {
                    Text("最近账单")
                        .font(.headline)
                    Spacer()
                    Button("查看全部", action: showAll)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.bottom, 8)

                if transactions.isEmpty {
                    ContentUnavailableView("还没有账单", systemImage: "leaf", description: Text("点击右上角 + 记下第一笔。"))
                        .frame(height: 170)
                } else {
                    ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
                        NavigationLink {
                            TransactionDetailView(transaction: transaction)
                        } label: {
                            TransactionRow(
                                transaction: transaction,
                                category: categoryMap[transaction.categoryID],
                                hideAmount: hideAmounts,
                                showsDisclosureIndicator: true
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("查看账单详情")
                        if index < transactions.count - 1 {
                            Divider().padding(.leading, 57)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState())
        .environmentObject(AppSettings.shared)
        .modelContainer(AppDatabase.preview.container)
}
