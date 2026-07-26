import SwiftUI
import SwiftData

struct CashPlanningView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \LedgerTransaction.occurredAt, order: .reverse) private var transactions: [LedgerTransaction]
    @Query(sort: \AccountBalanceAdjustment.occurredAt, order: .reverse) private var adjustments: [AccountBalanceAdjustment]
    @Query(sort: \MonthlyBudget.monthStart, order: .reverse) private var budgets: [MonthlyBudget]
    @Query(sort: \FinancialPlan.updatedAt, order: .reverse) private var plans: [FinancialPlan]

    @State private var isAddingPlan = false
    @State private var editingPlan: FinancialPlan?
    @State private var planToDelete: FinancialPlan?

    private var summary: CashAvailabilitySummary {
        CashAvailabilityCalculator.calculate(
            accounts: accounts,
            transactions: transactions,
            adjustments: adjustments,
            budgets: budgets,
            plans: plans
        )
    }

    private var livingPlans: [FinancialPlan] {
        activePlans(kinds: [.living, .majorPurchase])
    }

    private var investmentPlans: [FinancialPlan] {
        activePlans(kinds: [.investment])
    }

    private var reservePlans: [FinancialPlan] {
        activePlans(kinds: [.emergency, .travel, .education, .other])
    }

    private var inactivePlans: [FinancialPlan] {
        plans.filter { $0.status != .active }.sorted(by: planSort)
    }

    var body: some View {
        List {
            Section {
                CashAvailabilityHeader(summary: summary, hideAmounts: settings.hideAmounts)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            Section {
                CashBreakdownRow(
                    title: "流动资金",
                    detail: summary.investmentCashMinor > 0 ? "含投资账户现金" : "存款、现金与支付余额",
                    valueMinor: summary.liquidFundsMinor,
                    symbol: "banknote.fill",
                    tint: DaisyTheme.income,
                    hideAmount: settings.hideAmounts
                )
                CashBreakdownRow(
                    title: "计划预留",
                    detail: "进行中的资金计划",
                    valueMinor: summary.planReservedMinor,
                    symbol: "target",
                    tint: Color(hex: "5B8DEF"),
                    hideAmount: settings.hideAmounts
                )
                CashBreakdownRow(
                    title: "预算预留",
                    detail: "本月总预算剩余",
                    valueMinor: summary.budgetReservedMinor,
                    symbol: "gauge.with.dots.needle.67percent",
                    tint: DaisyTheme.warning,
                    hideAmount: settings.hideAmounts
                )
                if summary.cashShortfallMinor > 0 {
                    CashBreakdownRow(
                        title: "资金缺口",
                        detail: "预留金额高于流动资金",
                        valueMinor: summary.cashShortfallMinor,
                        symbol: "exclamationmark.triangle.fill",
                        tint: DaisyTheme.danger,
                        hideAmount: settings.hideAmounts
                    )
                }
            } header: {
                Text("资金构成")
            } footer: {
                Text("可用现金不会低于零。超额安排会作为资金缺口提示，但不会阻止保存计划。")
            }

            Section("管理") {
                NavigationLink {
                    BudgetSettingsView(month: Date())
                } label: {
                    Label("本月预算", systemImage: "gauge.with.dots.needle.67percent")
                }
                NavigationLink {
                    WealthOverviewView()
                } label: {
                    Label("账户与资产", systemImage: "building.columns.fill")
                }
            }

            planSection(title: "生活与固定支出", plans: livingPlans)
            planSection(title: "投资计划", plans: investmentPlans)
            planSection(title: "储备与目标", plans: reservePlans)

            if !inactivePlans.isEmpty {
                Section("已暂停、完成与归档") {
                    ForEach(inactivePlans) { plan in
                        planRow(plan)
                    }
                }
            }

            if plans.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("还没有资金计划", systemImage: "target")
                    } description: {
                        Text("添加生活、投资或储备目标，Daisy 会计算真正可使用的现金。")
                    } actions: {
                        Button("添加计划") { isAddingPlan = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("资金调度")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isAddingPlan = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("添加资金计划")
                    .accessibilityIdentifier("addFinancialPlanButton")
            }
        }
        .sheet(isPresented: $isAddingPlan) {
            FinancialPlanEditorView()
        }
        .sheet(item: $editingPlan) { plan in
            FinancialPlanEditorView(plan: plan)
        }
        .confirmationDialog(
            "删除“\(planToDelete?.name ?? "")”？",
            isPresented: Binding(
                get: { planToDelete != nil },
                set: { if !$0 { planToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("永久删除", role: .destructive) {
                if let planToDelete { delete(planToDelete) }
            }
            Button("取消", role: .cancel) { planToDelete = nil }
        } message: {
            Text("该计划会从资金调度和备份中移除，不会删除账户、资产或账单。")
        }
    }

    @ViewBuilder
    private func planSection(title: String, plans: [FinancialPlan]) -> some View {
        if !plans.isEmpty {
            Section {
                ForEach(plans) { plan in
                    planRow(plan)
                }
            } header: {
                Text(title)
            }
        }
    }

    private func planRow(_ plan: FinancialPlan) -> some View {
        Button { editingPlan = plan } label: {
            FinancialPlanRow(plan: plan, hideAmount: settings.hideAmounts)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("financialPlan.\(plan.id.uuidString)")
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if plan.status == .active {
                Button { setStatus(.paused, for: plan) } label: {
                    Label("暂停", systemImage: "pause.fill")
                }
                .tint(DaisyTheme.warning)
                Button { setStatus(.completed, for: plan) } label: {
                    Label("完成", systemImage: "checkmark")
                }
                .tint(DaisyTheme.income)
            } else {
                Button { setStatus(.active, for: plan) } label: {
                    Label("恢复", systemImage: "arrow.uturn.backward")
                }
                .tint(DaisyTheme.income)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { planToDelete = plan } label: {
                Label("删除", systemImage: "trash")
            }
            if plan.status != .archived {
                Button { setStatus(.archived, for: plan) } label: {
                    Label("归档", systemImage: "archivebox")
                }
                .tint(.secondary)
            }
        }
        .contextMenu {
            Button { editingPlan = plan } label: { Label("编辑", systemImage: "pencil") }
            if plan.status == .active {
                Button { setStatus(.paused, for: plan) } label: { Label("暂停", systemImage: "pause.fill") }
                Button { setStatus(.completed, for: plan) } label: { Label("标记完成", systemImage: "checkmark") }
            } else {
                Button { setStatus(.active, for: plan) } label: { Label("恢复进行", systemImage: "arrow.uturn.backward") }
            }
            if plan.status != .archived {
                Button { setStatus(.archived, for: plan) } label: { Label("归档", systemImage: "archivebox") }
            }
            Button(role: .destructive) { planToDelete = plan } label: { Label("删除", systemImage: "trash") }
        }
    }

    private func activePlans(kinds: Set<FinancialPlanKind>) -> [FinancialPlan] {
        plans.filter { $0.status == .active && kinds.contains($0.kind) }.sorted(by: planSort)
    }

    private func planSort(_ lhs: FinancialPlan, _ rhs: FinancialPlan) -> Bool {
        if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
        if lhs.targetDate != rhs.targetDate {
            return (lhs.targetDate ?? .distantFuture) < (rhs.targetDate ?? .distantFuture)
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private func setStatus(_ status: FinancialPlanStatus, for plan: FinancialPlan) {
        plan.status = status
        plan.updatedAt = Date()
        do {
            try modelContext.save()
            appState.presentToast(status == .active ? "计划已恢复" : "计划已\(status.title.dropFirst())")
        } catch {
            modelContext.rollback()
            appState.presentToast("计划更新失败", style: .error)
        }
    }

    private func delete(_ plan: FinancialPlan) {
        planToDelete = nil
        modelContext.delete(plan)
        do {
            try modelContext.save()
            appState.presentToast("计划已删除", style: .warning)
        } catch {
            modelContext.rollback()
            appState.presentToast("计划删除失败", style: .error)
        }
    }
}

private struct CashAvailabilityHeader: View {
    let summary: CashAvailabilitySummary
    let hideAmounts: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("当前可用现金")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.74))
                Text(render(summary.availableCashMinor))
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .accessibilityIdentifier("availableCashAmount")
            }
            HStack(spacing: 0) {
                headerMetric("流动资金", summary.liquidFundsMinor)
                Divider().overlay(.white.opacity(0.2)).padding(.horizontal, 16)
                headerMetric("资金占用", summary.occupiedCashMinor)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DaisyTheme.navy, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: DaisyTheme.navy.opacity(0.12), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
    }

    private func headerMetric(_ title: String, _ value: Int64) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.65))
            Text(render(value))
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func render(_ value: Int64) -> String {
        hideAmounts ? "••••" : Money(minorUnits: value).formatted()
    }
}

private struct CashBreakdownRow: View {
    let title: String
    let detail: String
    let valueMinor: Int64
    let symbol: String
    let tint: Color
    let hideAmount: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(hideAmount ? "••••" : Money(minorUnits: valueMinor).formatted())
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FinancialPlanRow: View {
    let plan: FinancialPlan
    let hideAmount: Bool

    private var remainingMinor: Int64 {
        max(0, plan.targetAmountMinor - plan.fundedMinor)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: plan.kind.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(plan.status == .active ? DaisyTheme.accent : Color.secondary)
                .frame(width: 38, height: 38)
                .background(
                    (plan.status == .active ? DaisyTheme.accent : Color.secondary).opacity(0.11),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(plan.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                    if plan.status != .active {
                        Text(plan.status.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Text(hideAmount ? "••••" : Money(minorUnits: plan.targetAmountMinor).formatted())
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                ProgressView(value: plan.progress)
                    .tint(plan.status == .active ? DaisyTheme.accent : Color.secondary)
                HStack {
                    Text("已安排 \(render(plan.fundedMinor))")
                    Spacer()
                    Text("待安排 \(render(remainingMinor))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if plan.reservedCashMinor > 0 || plan.heldAssetMinor > 0 {
                    Text("预留现金 \(render(plan.reservedCashMinor)) · 已持有资产 \(render(plan.heldAssetMinor))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func render(_ value: Int64) -> String {
        hideAmount ? "••••" : Money(minorUnits: value).formatted()
    }
}

private struct FinancialPlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \AssetHolding.sortOrder) private var assets: [AssetHolding]

    let plan: FinancialPlan?
    @State private var name: String
    @State private var kind: FinancialPlanKind
    @State private var targetText: String
    @State private var reservedText: String
    @State private var heldText: String
    @State private var cashSourceAccountID: UUID?
    @State private var linkedInvestmentAccountID: UUID?
    @State private var linkedAssetID: UUID?
    @State private var hasTargetDate: Bool
    @State private var targetDate: Date
    @State private var status: FinancialPlanStatus
    @State private var priority: Int
    @State private var note: String

    init(plan: FinancialPlan? = nil) {
        self.plan = plan
        _name = State(initialValue: plan?.name ?? "")
        _kind = State(initialValue: plan?.kind ?? .living)
        _targetText = State(initialValue: Self.text(for: plan?.targetAmountMinor))
        _reservedText = State(initialValue: plan.map { Self.text(for: $0.reservedCashMinor) } ?? "0.00")
        _heldText = State(initialValue: plan.map { Self.text(for: $0.heldAssetMinor) } ?? "0.00")
        _cashSourceAccountID = State(initialValue: plan?.cashSourceAccountID)
        _linkedInvestmentAccountID = State(initialValue: plan?.linkedInvestmentAccountID)
        _linkedAssetID = State(initialValue: plan?.linkedAssetID)
        _hasTargetDate = State(initialValue: plan?.targetDate != nil)
        _targetDate = State(initialValue: plan?.targetDate ?? Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date())
        _status = State(initialValue: plan?.status ?? .active)
        _priority = State(initialValue: plan?.priority ?? 1)
        _note = State(initialValue: plan?.note ?? "")
    }

    private var cashSourceAccounts: [Account] {
        accounts.filter {
            !$0.isArchived && $0.currencyCode == "CNY"
                && [.cash, .deposit, .payment, .investment].contains($0.wealthBucket)
        }
    }

    private var investmentAccounts: [Account] {
        accounts.filter { !$0.isArchived && $0.currencyCode == "CNY" && $0.wealthBucket == .investment }
    }

    private var activeAssets: [AssetHolding] {
        assets.filter { !$0.isArchived && $0.currencyCode == "CNY" && $0.nature == .asset }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && name.count <= 100
            && (Money(decimalString: targetText)?.minorUnits ?? 0) > 0
            && (Money(decimalString: reservedText)?.minorUnits ?? -1) >= 0
            && (Money(decimalString: heldText)?.minorUnits ?? -1) >= 0
            && note.count <= 2_000
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("计划") {
                    TextField("计划名称", text: $name)
                        .accessibilityIdentifier("financialPlanNameField")
                    Picker("类型", selection: $kind) {
                        ForEach(FinancialPlanKind.allCases) { kind in
                            Label(kind.title, systemImage: kind.systemImage).tag(kind)
                        }
                    }
                    Picker("优先级", selection: $priority) {
                        Text("普通").tag(0)
                        Text("重要").tag(1)
                        Text("优先").tag(2)
                        Text("最高").tag(3)
                    }
                }

                Section {
                    moneyField("目标金额", text: $targetText, identifier: "financialPlanTargetField")
                    moneyField("预留现金", text: $reservedText, identifier: "financialPlanReservedField")
                    moneyField("已持有资产", text: $heldText, identifier: "financialPlanHeldField")
                } header: {
                    Text("金额")
                } footer: {
                    Text("预留现金会减少可用现金；已持有资产只计入计划进度，不会再次计入总资产。")
                }

                Section("关联（可选）") {
                    Picker("现金来源", selection: $cashSourceAccountID) {
                        Text("不指定").tag(nil as UUID?)
                        ForEach(cashSourceAccounts) { account in
                            Text(account.name).tag(Optional(account.id))
                        }
                    }
                    Picker("投资账户", selection: $linkedInvestmentAccountID) {
                        Text("不指定").tag(nil as UUID?)
                        ForEach(investmentAccounts) { account in
                            Text(account.name).tag(Optional(account.id))
                        }
                    }
                    Picker("持有资产", selection: $linkedAssetID) {
                        Text("不指定").tag(nil as UUID?)
                        ForEach(activeAssets) { asset in
                            Text(asset.name).tag(Optional(asset.id))
                        }
                    }
                }

                Section {
                    Toggle("设置目标日期", isOn: $hasTargetDate)
                    if hasTargetDate {
                        DatePicker("目标日期", selection: $targetDate, displayedComponents: .date)
                    }
                    if plan != nil {
                        Picker("状态", selection: $status) {
                            ForEach(FinancialPlanStatus.allCases) { Text($0.title).tag($0) }
                        }
                    }
                    TextField("备注（可选）", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("时间与状态")
                }
            }
            .navigationTitle(plan == nil ? "添加资金计划" : "编辑资金计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                        .accessibilityIdentifier("saveFinancialPlanButton")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func moneyField(_ title: String, text: Binding<String>, identifier: String) -> some View {
        LabeledContent(title) {
            HStack(spacing: 5) {
                Text("¥").foregroundStyle(.secondary)
                TextField("0.00", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .accessibilityIdentifier(identifier)
            }
        }
    }

    private func save() {
        guard canSave,
              let target = Money(decimalString: targetText)?.minorUnits,
              let reserved = Money(decimalString: reservedText)?.minorUnits,
              let held = Money(decimalString: heldText)?.minorUnits else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetPlan = plan ?? FinancialPlan(
            name: trimmedName,
            kind: kind,
            targetAmountMinor: target
        )
        if plan == nil { modelContext.insert(targetPlan) }
        targetPlan.name = trimmedName
        targetPlan.kind = kind
        targetPlan.targetAmountMinor = target
        targetPlan.reservedCashMinor = reserved
        targetPlan.heldAssetMinor = held
        targetPlan.cashSourceAccountID = cashSourceAccountID
        targetPlan.linkedInvestmentAccountID = linkedInvestmentAccountID
        targetPlan.linkedAssetID = linkedAssetID
        targetPlan.targetDate = hasTargetDate ? targetDate : nil
        targetPlan.status = status
        targetPlan.priority = priority
        targetPlan.note = trimmedNote
        targetPlan.updatedAt = Date()
        do {
            try modelContext.save()
            appState.presentToast(plan == nil ? "资金计划已添加" : "资金计划已更新")
            dismiss()
        } catch {
            modelContext.rollback()
            appState.presentToast("资金计划保存失败", style: .error)
        }
    }

    private static func text(for value: Int64?) -> String {
        guard let value else { return "" }
        return NSDecimalNumber(decimal: Money(minorUnits: value).decimalValue).stringValue
    }
}
