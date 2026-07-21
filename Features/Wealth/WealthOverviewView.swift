import SwiftUI
import SwiftData
import Charts

struct WealthOverviewView: View {
    private enum AddSheet: String, Identifiable {
        case account
        case asset
        case liability

        var id: String { rawValue }
    }

    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \LedgerTransaction.occurredAt, order: .reverse) private var transactions: [LedgerTransaction]
    @Query(sort: \AccountBalanceAdjustment.occurredAt, order: .reverse) private var adjustments: [AccountBalanceAdjustment]
    @Query(sort: \AssetHolding.sortOrder) private var holdings: [AssetHolding]
    @State private var addSheet: AddSheet?

    private var summary: WealthSummary {
        WealthSummaryCalculator.calculate(
            accounts: accounts,
            transactions: transactions,
            adjustments: adjustments,
            assets: holdings
        )
    }

    private var financialAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    private var assetHoldings: [AssetHolding] {
        holdings.filter { !$0.isArchived && $0.nature == .asset }
    }

    private var liabilityHoldings: [AssetHolding] {
        holdings.filter { !$0.isArchived && $0.nature == .liability }
    }

    private var archivedAccounts: [Account] { accounts.filter(\.isArchived) }
    private var archivedHoldings: [AssetHolding] { holdings.filter(\.isArchived) }

    private var composition: [WealthComposition] {
        [
            WealthComposition(id: "deposit", title: "存款", valueMinor: summary.totalDepositsMinor, tint: DaisyTheme.accent, symbol: "building.columns.fill"),
            WealthComposition(id: "liquid", title: "现金与支付", valueMinor: max(0, summary.liquidFundsMinor - summary.totalDepositsMinor), tint: Color(hex: "5B8DEF"), symbol: "wallet.pass.fill"),
            WealthComposition(id: "investment", title: "投资", valueMinor: summary.investmentAssetsMinor, tint: Color(hex: "7A6FF0"), symbol: "chart.line.uptrend.xyaxis"),
            WealthComposition(id: "other", title: "其他资产", valueMinor: summary.otherAssetsMinor, tint: Color(hex: "D99058"), symbol: "house.fill")
        ].filter { $0.valueMinor > 0 }
    }

    var body: some View {
        List {
            Section {
                WealthSummaryHeader(summary: summary, hideAmounts: settings.hideAmounts)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 16, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            if !composition.isEmpty {
                Section("资产构成") {
                    Chart(composition) { item in
                        SectorMark(
                            angle: .value("金额", item.valueMinor),
                            innerRadius: .ratio(0.66),
                            angularInset: 2
                        )
                        .cornerRadius(4)
                        .foregroundStyle(item.tint)
                    }
                    .frame(height: 180)
                    .accessibilityLabel("资产构成图")

                    ForEach(composition) { item in
                        WealthCompositionRow(item: item, hideAmount: settings.hideAmounts)
                    }
                }
            }

            Section {
                if financialAccounts.isEmpty {
                    Text("还没有金融账户")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(financialAccounts) { account in
                        NavigationLink {
                            AccountWealthDetailView(account: account)
                        } label: {
                            WealthAccountRow(
                                account: account,
                                transactions: transactions,
                                adjustments: adjustments,
                                hideAmount: settings.hideAmounts
                            )
                        }
                    }
                }
            } header: {
                Text("金融账户")
            } footer: {
                Text("账户余额由期初余额、账单、转账和余额校准共同计算。")
            }

            if !assetHoldings.isEmpty {
                Section("其他资产") {
                    ForEach(assetHoldings) { asset in
                        NavigationLink {
                            AssetHoldingDetailView(asset: asset)
                        } label: {
                            WealthHoldingRow(asset: asset, hideAmount: settings.hideAmounts)
                        }
                    }
                }
            }

            if !liabilityHoldings.isEmpty {
                Section("其他负债") {
                    ForEach(liabilityHoldings) { asset in
                        NavigationLink {
                            AssetHoldingDetailView(asset: asset)
                        } label: {
                            WealthHoldingRow(asset: asset, hideAmount: settings.hideAmounts)
                        }
                    }
                }
            }

            if !archivedAccounts.isEmpty || !archivedHoldings.isEmpty {
                Section {
                    ForEach(archivedAccounts) { account in
                        NavigationLink {
                            AccountWealthDetailView(account: account)
                        } label: {
                            WealthAccountRow(
                                account: account,
                                transactions: transactions,
                                adjustments: adjustments,
                                hideAmount: settings.hideAmounts
                            )
                        }
                    }
                    ForEach(archivedHoldings) { asset in
                        NavigationLink {
                            AssetHoldingDetailView(asset: asset)
                        } label: {
                            WealthHoldingRow(asset: asset, hideAmount: settings.hideAmounts)
                        }
                    }
                } header: {
                    Text("已归档")
                } footer: {
                    Text("归档项目不会计入当前资产汇总，但历史账单和估值记录仍会保留。")
                }
            }

            if summary.foreignItemCount > 0 {
                Section {
                    Label(
                        "有 \(summary.foreignItemCount) 个外币项目未计入人民币汇总",
                        systemImage: "exclamationmark.circle"
                    )
                    .foregroundStyle(DaisyTheme.warning)
                } footer: {
                    Text("当前版本不自动换算外币，外币余额仍会在账户明细中保留。")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("资产")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        addSheet = .account
                    } label: {
                        Label("添加金融账户", systemImage: "building.columns.fill")
                    }
                    Button {
                        addSheet = .asset
                    } label: {
                        Label("添加其他资产", systemImage: "plus.circle")
                    }
                    Button {
                        addSheet = .liability
                    } label: {
                        Label("添加负债", systemImage: "creditcard.fill")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("添加资产或账户")
            }
        }
        .sheet(item: $addSheet) { sheet in
            switch sheet {
            case .account:
                AccountEditorView()
            case .asset:
                AssetHoldingEditorView(nature: .asset)
            case .liability:
                AssetHoldingEditorView(nature: .liability)
            }
        }
    }
}

private struct WealthSummaryHeader: View {
    let summary: WealthSummary
    let hideAmounts: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("净资产")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(render(summary.netWorthMinor))
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold).monospacedDigit())
                    .foregroundStyle(summary.netWorthMinor < 0 ? DaisyTheme.danger : .primary)
                    .minimumScaleFactor(0.75)
            }

            HStack(spacing: 0) {
                WealthMetric(title: "总存款", value: render(summary.totalDepositsMinor), tint: DaisyTheme.accent)
                Divider().frame(height: 34).padding(.horizontal, 16)
                WealthMetric(title: "总资产", value: render(summary.totalAssetsMinor), tint: .primary)
                Divider().frame(height: 34).padding(.horizontal, 16)
                WealthMetric(title: "负债", value: render(summary.totalLiabilitiesMinor), tint: DaisyTheme.danger)
            }
        }
    }

    private func render(_ value: Int64) -> String {
        hideAmounts ? "••••" : Money(minorUnits: value).formatted()
    }
}

private struct WealthMetric: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WealthComposition: Identifiable {
    let id: String
    let title: String
    let valueMinor: Int64
    let tint: Color
    let symbol: String
}

private struct WealthCompositionRow: View {
    let item: WealthComposition
    let hideAmount: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(item.tint).frame(width: 9, height: 9)
            Label(item.title, systemImage: item.symbol)
                .font(.subheadline)
            Spacer()
            Text(hideAmount ? "••••" : Money(minorUnits: item.valueMinor).formatted())
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hideAmount ? "\(item.title)，金额已隐藏" : "\(item.title)，\(Money(minorUnits: item.valueMinor).formatted())")
    }
}

private struct WealthAccountRow: View {
    let account: Account
    let transactions: [LedgerTransaction]
    let adjustments: [AccountBalanceAdjustment]
    let hideAmount: Bool

    private var balance: Int64 {
        AccountBalanceCalculator.balanceMinor(
            for: account,
            transactions: transactions,
            adjustments: adjustments
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: account.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DaisyTheme.accent)
                .frame(width: 38, height: 38)
                .background(DaisyTheme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .font(.body.weight(.medium))
                Text(account.wealthBucket.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(hideAmount ? "••••" : Money(minorUnits: balance, currencyCode: account.currencyCode).formatted())
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(balance < 0 ? DaisyTheme.danger : .primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            hideAmount
                ? "\(account.name)，金额已隐藏"
                : "\(account.name)，\(Money(minorUnits: balance, currencyCode: account.currencyCode).formatted())"
        )
    }
}

private struct WealthHoldingRow: View {
    let asset: AssetHolding
    let hideAmount: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: asset.kind.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(asset.nature == .liability ? DaisyTheme.danger : DaisyTheme.accent)
                .frame(width: 38, height: 38)
                .background(
                    (asset.nature == .liability ? DaisyTheme.danger : DaisyTheme.accent).opacity(0.11),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name).font(.body.weight(.medium))
                Text(asset.kind.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(hideAmount ? "••••" : Money(minorUnits: asset.currentValueMinor, currencyCode: asset.currencyCode).formatted())
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(asset.nature == .liability ? DaisyTheme.danger : .primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            hideAmount
                ? "\(asset.name)，金额已隐藏"
                : "\(asset.name)，\(Money(minorUnits: asset.currentValueMinor, currencyCode: asset.currencyCode).formatted())"
        )
    }
}

private struct AccountWealthDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \LedgerTransaction.occurredAt, order: .reverse) private var transactions: [LedgerTransaction]
    @Query(sort: \AccountBalanceAdjustment.occurredAt, order: .reverse) private var adjustments: [AccountBalanceAdjustment]
    @Bindable var account: Account
    @State private var showingEditor = false
    @State private var showingAdjustment = false

    private var balance: Int64 {
        AccountBalanceCalculator.balanceMinor(for: account, transactions: transactions, adjustments: adjustments)
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: account.symbol)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(DaisyTheme.accent)
                        .frame(width: 48, height: 48)
                        .background(DaisyTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text(settings.hideAmounts ? "••••" : Money(minorUnits: balance, currencyCode: account.currencyCode).formatted())
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold).monospacedDigit())
                        .foregroundStyle(balance < 0 ? DaisyTheme.danger : .primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .listRowBackground(Color.clear)
            }
            Section("账户信息") {
                LabeledContent("类型", value: account.type.title)
                LabeledContent("资产分组", value: account.wealthBucket.title)
                LabeledContent("币种", value: account.currencyCode)
                Toggle("计入净资产", isOn: $account.includeInNetWorth)
                    .onChange(of: account.includeInNetWorth) { _, _ in
                        account.updatedAt = Date()
                        do {
                            try modelContext.save()
                        } catch {
                            modelContext.rollback()
                            appState.presentToast("账户设置保存失败", style: .error)
                        }
                    }
            }
            Section("余额") {
                Button {
                    showingAdjustment = true
                } label: {
                    Label("校准当前余额", systemImage: "slider.horizontal.3")
                }
                Text("余额校准不会生成收入或支出账单，只用于让资产汇总与真实余额一致。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !adjustments.filter({ $0.accountID == account.id }).isEmpty {
                Section("校准记录") {
                    ForEach(adjustments.filter { $0.accountID == account.id }) { adjustment in
                        HStack {
                            Text(adjustment.occurredAt.formatted(date: .abbreviated, time: .shortened))
                            Spacer()
                            Text(Money(minorUnits: adjustment.deltaMinor).formatted(showCode: false))
                                .font(.body.monospacedDigit())
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Button("编辑账户", systemImage: "pencil") { showingEditor = true }
                Button(account.isArchived ? "恢复账户" : "归档账户", systemImage: account.isArchived ? "arrow.uturn.backward" : "archivebox") {
                    account.isArchived.toggle()
                    account.updatedAt = Date()
                    do {
                        try modelContext.save()
                        appState.presentToast(account.isArchived ? "账户已归档" : "账户已恢复")
                        if account.isArchived { dismiss() }
                    } catch {
                        modelContext.rollback()
                        appState.presentToast("账户更新失败", style: .error)
                    }
                }
                .foregroundStyle(account.isArchived ? DaisyTheme.income : DaisyTheme.warning)
            }
        }
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditor) { AccountEditorView(account: account) }
        .sheet(isPresented: $showingAdjustment) { AccountBalanceAdjustmentView(account: account, currentBalance: balance) }
    }
}

private struct AccountEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    let account: Account?
    @State private var name: String
    @State private var type: AccountType
    @State private var bucket: WealthBucket
    @State private var openingBalanceText: String
    @State private var includeInNetWorth: Bool

    init(account: Account? = nil) {
        self.account = account
        _name = State(initialValue: account?.name ?? "")
        _type = State(initialValue: account?.type ?? .bank)
        _bucket = State(initialValue: account?.wealthBucket ?? .deposit)
        _openingBalanceText = State(initialValue: account.map {
            NSDecimalNumber(decimal: Money(minorUnits: $0.openingBalanceMinor).decimalValue).stringValue
        } ?? "0.00")
        _includeInNetWorth = State(initialValue: account?.includeInNetWorth ?? true)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Money(decimalString: openingBalanceText) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("账户") {
                    TextField("账户名称", text: $name)
                    Picker("类型", selection: $type) {
                        ForEach(AccountType.allCases) { Text($0.title).tag($0) }
                    }
                    Picker("资产分组", selection: $bucket) {
                        ForEach(WealthBucket.allCases) { Text($0.title).tag($0) }
                    }
                    LabeledContent("币种", value: "CNY")
                }
                if account == nil {
                    Section {
                        TextField(bucket == .liability ? "当前欠款" : "期初余额", text: $openingBalanceText)
                            .keyboardType(.numbersAndPunctuation)
                    } footer: {
                        Text(bucket == .liability ? "请输入欠款金额；保存后会以负余额计入负债。" : "期初余额不会计入本月收入。")
                    }
                }
                Section {
                    Toggle("计入净资产", isOn: $includeInNetWorth)
                } footer: {
                    Text("关闭后，该账户仍保留，但不会进入资产汇总。")
                }
            }
            .navigationTitle(account == nil ? "添加金融账户" : "编辑账户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onChange(of: type) { _, newType in
                if account == nil { bucket = newType.defaultWealthBucket }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        guard canSave, let parsed = Money(decimalString: openingBalanceText) else { return }
        let openingBalance = bucket == .liability ? -abs(parsed.minorUnits) : parsed.minorUnits
        let target = account ?? Account(
            name: name,
            type: type,
            symbol: typeSymbol,
            openingBalanceMinor: openingBalance,
            sortOrder: accounts.count,
            wealthBucket: bucket,
            includeInNetWorth: includeInNetWorth
        )
        if account == nil { modelContext.insert(target) }
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.typeRaw = type.rawValue
        target.symbol = typeSymbol
        target.wealthBucket = bucket
        target.includeInNetWorth = includeInNetWorth
        target.updatedAt = Date()
        do {
            try modelContext.save()
            appState.presentToast(account == nil ? "账户已添加" : "账户已更新")
            dismiss()
        } catch {
            modelContext.rollback()
            appState.presentToast("账户保存失败", style: .error)
        }
    }

    private var typeSymbol: String {
        switch type {
        case .cash: "banknote.fill"
        case .bank, .savings, .termDeposit: "building.columns.fill"
        case .creditCard: "creditcard.fill"
        case .paymentChannel: "wallet.pass.fill"
        case .investment: "chart.line.uptrend.xyaxis"
        case .loan: "banknote.fill"
        case .other: "circle.grid.2x2.fill"
        }
    }
}

private struct AccountBalanceAdjustmentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    let account: Account
    let currentBalance: Int64
    @State private var targetBalanceText: String
    @State private var note = ""

    init(account: Account, currentBalance: Int64) {
        self.account = account
        self.currentBalance = currentBalance
        _targetBalanceText = State(initialValue: NSDecimalNumber(decimal: Money(minorUnits: currentBalance).decimalValue).stringValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("校准后的余额", text: $targetBalanceText)
                        .keyboardType(.numbersAndPunctuation)
                        .font(.title2.monospacedDigit().weight(.semibold))
                    TextField("原因（可选）", text: $note)
                } footer: {
                    Text("当前余额：\(Money(minorUnits: currentBalance, currencyCode: account.currencyCode).formatted())。校准只影响资产余额，不会生成账单。")
                }
            }
            .navigationTitle("校准余额")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                        .disabled(Money(decimalString: targetBalanceText) == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let target = Money(decimalString: targetBalanceText)?.minorUnits else { return }
        let delta = target - currentBalance
        guard delta != 0 else {
            dismiss()
            return
        }
        modelContext.insert(AccountBalanceAdjustment(
            accountID: account.id,
            deltaMinor: delta,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        do {
            try modelContext.save()
            appState.presentToast("余额已校准")
            dismiss()
        } catch {
            modelContext.rollback()
            appState.presentToast("余额校准失败", style: .error)
        }
    }
}

private struct AssetHoldingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \AssetValuation.recordedAt, order: .reverse) private var valuations: [AssetValuation]
    @Bindable var asset: AssetHolding
    @State private var showingEditor = false
    @State private var showingValuation = false

    private var history: [AssetValuation] {
        valuations.filter { $0.assetID == asset.id }
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: asset.kind.systemImage)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(asset.nature == .liability ? DaisyTheme.danger : DaisyTheme.accent)
                    Text(settings.hideAmounts ? "••••" : Money(minorUnits: asset.currentValueMinor, currencyCode: asset.currencyCode).formatted())
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold).monospacedDigit())
                        .foregroundStyle(asset.nature == .liability ? DaisyTheme.danger : .primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .listRowBackground(Color.clear)
            }
            Section(asset.nature == .asset ? "资产信息" : "负债信息") {
                LabeledContent("类型", value: asset.kind.title)
                if !asset.institution.isEmpty { LabeledContent("机构/位置", value: asset.institution) }
                LabeledContent(asset.nature == .asset ? "最近估值" : "最近余额", value: asset.valuationDate.formatted(date: .abbreviated, time: .omitted))
                if let cost = asset.costMinor {
                    LabeledContent("记录成本", value: settings.hideAmounts ? "••••" : Money(minorUnits: cost, currencyCode: asset.currencyCode).formatted())
                    let gain = asset.currentValueMinor - cost
                    LabeledContent("估值变化", value: settings.hideAmounts ? "••••" : Money(minorUnits: gain, currencyCode: asset.currencyCode).formatted())
                }
                Toggle("计入净资产", isOn: $asset.includeInNetWorth)
                    .onChange(of: asset.includeInNetWorth) { _, _ in
                        asset.updatedAt = Date()
                        do {
                            try modelContext.save()
                        } catch {
                            modelContext.rollback()
                            appState.presentToast("资产设置保存失败", style: .error)
                        }
                    }
            }
            if !asset.note.isEmpty { Section("备注") { Text(asset.note) } }
            if !history.isEmpty {
                Section(asset.nature == .asset ? "估值记录" : "余额记录") {
                    ForEach(history) { valuation in
                        HStack {
                            Text(valuation.recordedAt.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text(settings.hideAmounts ? "••••" : Money(minorUnits: valuation.valueMinor, currencyCode: asset.currencyCode).formatted())
                                .font(.body.monospacedDigit())
                        }
                    }
                }
            }
            Section {
                Button(asset.nature == .asset ? "更新估值" : "更新欠款", systemImage: "chart.line.uptrend.xyaxis") { showingValuation = true }
                Button(asset.nature == .asset ? "编辑资产" : "编辑负债", systemImage: "pencil") { showingEditor = true }
                Button(archiveActionTitle, systemImage: asset.isArchived ? "arrow.uturn.backward" : "archivebox") {
                    asset.isArchived.toggle()
                    asset.updatedAt = Date()
                    do {
                        try modelContext.save()
                        appState.presentToast(archiveSuccessMessage)
                        if asset.isArchived { dismiss() }
                    } catch {
                        modelContext.rollback()
                        appState.presentToast(asset.nature == .asset ? "资产更新失败" : "负债更新失败", style: .error)
                    }
                }
                .foregroundStyle(asset.isArchived ? DaisyTheme.income : DaisyTheme.warning)
            }
        }
        .navigationTitle(asset.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditor) { AssetHoldingEditorView(asset: asset) }
        .sheet(isPresented: $showingValuation) { AssetValuationEditorView(asset: asset) }
    }

    private var archiveActionTitle: String {
        let item = asset.nature == .asset ? "资产" : "负债"
        return asset.isArchived ? "恢复\(item)" : "归档\(item)"
    }

    private var archiveSuccessMessage: String {
        let item = asset.nature == .asset ? "资产" : "负债"
        return asset.isArchived ? "\(item)已归档" : "\(item)已恢复"
    }
}

private struct AssetHoldingEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \AssetHolding.sortOrder) private var holdings: [AssetHolding]

    let asset: AssetHolding?
    let nature: WealthItemNature
    @State private var name: String
    @State private var kind: AssetKind
    @State private var valueText: String
    @State private var costText: String
    @State private var institution: String
    @State private var note: String
    @State private var valuationDate: Date
    @State private var includeInNetWorth: Bool

    init(asset: AssetHolding? = nil, nature: WealthItemNature = .asset) {
        self.asset = asset
        self.nature = asset?.nature ?? nature
        _name = State(initialValue: asset?.name ?? "")
        _kind = State(initialValue: asset?.kind ?? (nature == .asset ? .otherAsset : .otherLiability))
        _valueText = State(initialValue: asset.map { NSDecimalNumber(decimal: Money(minorUnits: $0.currentValueMinor).decimalValue).stringValue } ?? "")
        _costText = State(initialValue: asset?.costMinor.map { NSDecimalNumber(decimal: Money(minorUnits: $0).decimalValue).stringValue } ?? "")
        _institution = State(initialValue: asset?.institution ?? "")
        _note = State(initialValue: asset?.note ?? "")
        _valuationDate = State(initialValue: asset?.valuationDate ?? Date())
        _includeInNetWorth = State(initialValue: asset?.includeInNetWorth ?? true)
    }

    private var kinds: [AssetKind] { AssetKind.allCases.filter { $0.nature == nature } }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (Money(decimalString: valueText)?.minorUnits ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("项目") {
                    TextField(nature == .asset ? "资产名称" : "负债名称", text: $name)
                    Picker("类型", selection: $kind) {
                        ForEach(kinds) { Text($0.title).tag($0) }
                    }
                    HStack {
                        Text("¥").foregroundStyle(.secondary)
                        TextField(nature == .asset ? "当前价值" : "当前欠款", text: $valueText)
                            .keyboardType(.decimalPad)
                            .font(.title2.monospacedDigit().weight(.semibold))
                    }
                    if nature == .asset {
                        TextField("记录成本（可选）", text: $costText)
                            .keyboardType(.decimalPad)
                    }
                }
                Section("补充信息") {
                    TextField("机构或位置（可选）", text: $institution)
                    DatePicker("估值日期", selection: $valuationDate, displayedComponents: .date)
                    TextField("备注（可选）", text: $note, axis: .vertical)
                    Toggle("计入净资产", isOn: $includeInNetWorth)
                }
            }
            .navigationTitle(asset == nil ? (nature == .asset ? "添加其他资产" : "添加负债") : (nature == .asset ? "编辑资产" : "编辑负债"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        guard canSave, let value = Money(decimalString: valueText)?.minorUnits else { return }
        let cost = nature == .asset ? Money(decimalString: costText)?.minorUnits : nil
        let target = asset ?? AssetHolding(
            name: name,
            kind: kind,
            nature: nature,
            currentValueMinor: value,
            costMinor: cost,
            institution: institution,
            note: note,
            valuationDate: valuationDate,
            includeInNetWorth: includeInNetWorth,
            sortOrder: holdings.count
        )
        if asset == nil { modelContext.insert(target) }
        let valueChanged = asset == nil || target.currentValueMinor != value
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.kind = kind
        target.currentValueMinor = value
        target.costMinor = cost
        target.institution = institution.trimmingCharacters(in: .whitespacesAndNewlines)
        target.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        target.valuationDate = valuationDate
        target.includeInNetWorth = includeInNetWorth
        target.updatedAt = Date()
        if valueChanged {
            modelContext.insert(AssetValuation(assetID: target.id, valueMinor: value, recordedAt: valuationDate))
        }
        do {
            try modelContext.save()
            let item = nature == .asset ? "资产" : "负债"
            appState.presentToast(asset == nil ? "\(item)已添加" : "\(item)已更新")
            dismiss()
        } catch {
            modelContext.rollback()
            appState.presentToast(nature == .asset ? "资产保存失败" : "负债保存失败", style: .error)
        }
    }
}

private struct AssetValuationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    let asset: AssetHolding
    @State private var valueText: String
    @State private var date: Date
    @State private var note = ""

    init(asset: AssetHolding) {
        self.asset = asset
        _valueText = State(initialValue: NSDecimalNumber(decimal: Money(minorUnits: asset.currentValueMinor).decimalValue).stringValue)
        _date = State(initialValue: Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(asset.nature == .asset ? "当前价值" : "当前欠款", text: $valueText)
                    .keyboardType(.decimalPad)
                    .font(.title2.monospacedDigit().weight(.semibold))
                DatePicker("记录日期", selection: $date, displayedComponents: .date)
                TextField("备注（可选）", text: $note, axis: .vertical)
            }
            .navigationTitle(asset.nature == .asset ? "更新估值" : "更新欠款")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                        .disabled((Money(decimalString: valueText)?.minorUnits ?? 0) <= 0)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let value = Money(decimalString: valueText)?.minorUnits, value > 0 else { return }
        asset.currentValueMinor = value
        asset.valuationDate = date
        asset.updatedAt = Date()
        modelContext.insert(AssetValuation(
            assetID: asset.id,
            valueMinor: value,
            recordedAt: date,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        do {
            try modelContext.save()
            appState.presentToast(asset.nature == .asset ? "估值已更新" : "欠款已更新")
            dismiss()
        } catch {
            modelContext.rollback()
            appState.presentToast(asset.nature == .asset ? "估值更新失败" : "欠款更新失败", style: .error)
        }
    }
}
