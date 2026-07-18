import SwiftUI
import SwiftData

struct RecurringRemindersView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var settings: AppSettings
    @Query(sort: \RecurringReminder.dayOfMonth) private var reminders: [RecurringReminder]

    @State private var isAdding = false
    @State private var editingReminder: RecurringReminder?

    var body: some View {
        List {
            if reminders.isEmpty {
                ContentUnavailableView {
                    Label("还没有周期提醒", systemImage: "calendar.badge.clock")
                } description: {
                    Text("为房租、订阅等固定账单设置本地提醒。")
                } actions: {
                    Button("添加提醒") { isAdding = true }
                        .buttonStyle(.borderedProminent)
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(reminders) { reminder in
                    Button {
                        editingReminder = reminder
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: reminder.isEnabled ? "bell.badge.fill" : "bell.slash.fill")
                                .foregroundStyle(reminder.isEnabled ? DaisyTheme.accent : .secondary)
                                .frame(width: 36, height: 36)
                                .background(
                                    (reminder.isEnabled ? DaisyTheme.accent : Color.secondary).opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reminder.merchant)
                                    .font(.body.weight(.medium))
                                Text("每月 \(reminder.dayOfMonth) 日 · 09:00")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Text(settings.hideAmounts ? "••••" : Money(minorUnits: reminder.amountMinor).formatted())
                                .font(.body.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.primary)
                                .accessibilityLabel(
                                    settings.hideAmounts
                                        ? "金额已隐藏"
                                        : Money(minorUnits: reminder.amountMinor).formatted()
                                )
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            delete(reminder)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("周期提醒")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAdding = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("添加周期提醒")
                .accessibilityIdentifier("addRecurringReminderButton")
            }
        }
        .sheet(isPresented: $isAdding) {
            RecurringReminderEditorView()
        }
        .sheet(item: $editingReminder) { reminder in
            RecurringReminderEditorView(reminder: reminder)
        }
    }

    private func delete(_ reminder: RecurringReminder) {
        modelContext.delete(reminder)
        do {
            try modelContext.save()
            RecurringReminderScheduler.remove(reminderID: reminder.id)
            appState.presentToast("周期提醒已删除", style: .warning)
        } catch {
            modelContext.rollback()
            appState.presentToast("删除失败，请重试", style: .error)
        }
    }
}

private struct RecurringReminderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]

    let reminder: RecurringReminder?

    @State private var merchant: String
    @State private var amountText: String
    @State private var categoryID: String
    @State private var accountID: UUID?
    @State private var dayOfMonth: Int
    @State private var isEnabled: Bool
    @State private var isSaving = false

    private var expenseCategories: [LedgerCategory] {
        categories.filter { $0.kind == .expense }
    }

    private var canSave: Bool {
        !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (Money(decimalString: amountText)?.minorUnits ?? 0) > 0
            && !categoryID.isEmpty
            && !isSaving
    }

    init(reminder: RecurringReminder? = nil) {
        self.reminder = reminder
        _merchant = State(initialValue: reminder?.merchant ?? "")
        _amountText = State(initialValue: reminder.map {
            NSDecimalNumber(decimal: Money(minorUnits: $0.amountMinor).decimalValue).stringValue
        } ?? "")
        _categoryID = State(initialValue: reminder?.categoryID ?? "")
        _accountID = State(initialValue: reminder?.accountID)
        _dayOfMonth = State(initialValue: reminder?.dayOfMonth ?? Calendar.current.component(.day, from: Date()))
        _isEnabled = State(initialValue: reminder?.isEnabled ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("账单") {
                    TextField("商户或用途", text: $merchant)
                        .accessibilityIdentifier("recurringMerchantField")
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("¥")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2.monospacedDigit().weight(.semibold))
                            .accessibilityIdentifier("recurringAmountField")
                    }
                    Picker("分类", selection: $categoryID) {
                        ForEach(expenseCategories) { category in
                            Label(category.name, systemImage: category.symbol)
                                .tag(category.id)
                        }
                    }
                    Picker("账户", selection: $accountID) {
                        Text("未指定").tag(Optional<UUID>.none)
                        ForEach(accounts.filter { !$0.isArchived || $0.id == accountID }) { account in
                            Label(account.name, systemImage: account.symbol)
                                .tag(Optional(account.id))
                        }
                    }
                }

                Section {
                    Stepper("每月 \(dayOfMonth) 日", value: $dayOfMonth, in: 1...28)
                    Toggle("启用提醒", isOn: $isEnabled)
                } header: {
                    Text("提醒")
                } footer: {
                    Text("每月当天 09:00 提醒。Daisy 不会自动入账，需由你确认保存。")
                }
            }
            .navigationTitle(reminder == nil ? "添加周期提醒" : "编辑周期提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                    .accessibilityIdentifier("saveRecurringReminderButton")
                }
            }
            .onAppear {
                if categoryID.isEmpty { categoryID = expenseCategories.first?.id ?? "" }
                if accountID == nil { accountID = accounts.first(where: { !$0.isArchived })?.id }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @MainActor
    private func save() async {
        guard canSave,
              let amountMinor = Money(decimalString: amountText)?.minorUnits else { return }
        isSaving = true
        defer { isSaving = false }

        let target = reminder ?? RecurringReminder(
            merchant: merchant,
            amountMinor: amountMinor,
            categoryID: categoryID,
            accountID: accountID,
            dayOfMonth: dayOfMonth,
            isEnabled: isEnabled
        )
        if reminder == nil { modelContext.insert(target) }
        target.merchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        target.amountMinor = amountMinor
        target.categoryID = categoryID
        target.accountID = accountID
        target.dayOfMonth = dayOfMonth
        target.isEnabled = isEnabled
        target.updatedAt = Date()

        do {
            let scheduled = try await RecurringReminderScheduler.schedule(target)
            if target.isEnabled && !scheduled { target.isEnabled = false }
            try modelContext.save()
            dismiss()
            appState.presentToast(
                scheduled ? "周期提醒已保存" : "已保存，请在系统设置中开启通知",
                style: scheduled ? .success : .warning
            )
        } catch {
            RecurringReminderScheduler.remove(reminderID: target.id)
            modelContext.rollback()
            if let reminder, reminder.isEnabled {
                _ = try? await RecurringReminderScheduler.schedule(reminder)
            }
            appState.presentToast("提醒保存失败，请重试", style: .error)
        }
    }
}
