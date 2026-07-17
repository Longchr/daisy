import SwiftUI
import SwiftData

struct BudgetSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \MonthlyBudget.monthStart, order: .reverse) private var budgets: [MonthlyBudget]
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]

    @State private var selectedMonth = Date()
    @State private var amountText = ""
    @State private var isAddingCategoryBudget = false
    @State private var editingCategoryBudget: MonthlyBudget?

    private var existing: MonthlyBudget? {
        budgets.first {
            $0.categoryID == nil && Calendar.current.isDate($0.monthStart, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    private var categoryBudgets: [MonthlyBudget] {
        budgets.filter {
            $0.categoryID != nil
                && Calendar.current.isDate($0.monthStart, equalTo: selectedMonth, toGranularity: .month)
        }.sorted {
            categoryName(for: $0).localizedStandardCompare(categoryName(for: $1)) == .orderedAscending
        }
    }

    var body: some View {
        Form {
            Section {
                DatePicker("预算月份", selection: $selectedMonth, displayedComponents: .date)
                    .datePickerStyle(.compact)
                HStack(alignment: .firstTextBaseline) {
                    Text("¥").foregroundStyle(.secondary)
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title2.monospacedDigit().weight(.semibold))
                }
            } header: {
                Text("总预算")
            } footer: {
                Text("预算只影响提醒和分析，不会限制记账。退款会抵扣对应支出。")
            }

            Section {
                Button(existing == nil ? "保存预算" : "更新预算", action: save)
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
                    .disabled((Money(decimalString: amountText)?.minorUnits ?? 0) <= 0)
            }

            if let existing {
                Section {
                    Button("删除本月预算", role: .destructive) {
                        modelContext.delete(existing)
                        try? modelContext.save()
                        amountText = ""
                    }
                }
            }

            Section {
                ForEach(categoryBudgets) { budget in
                    Button {
                        editingCategoryBudget = budget
                    } label: {
                        HStack(spacing: 12) {
                            let category = categories.first { $0.id == budget.categoryID }
                            CategoryIcon(
                                symbol: category?.symbol ?? "tag.fill",
                                tint: Color(hex: category?.tintHex ?? "8A8A8E"),
                                size: 36
                            )
                            Text(category?.name ?? "未知分类")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(Money(minorUnits: budget.amountMinor).formatted())
                                .font(.body.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            delete(budget)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }

                Button {
                    isAddingCategoryBudget = true
                } label: {
                    Label("添加分类预算", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("分类预算")
            } footer: {
                Text("分类预算用于观察消费边界，不会阻止记账。")
            }
        }
        .navigationTitle("月度预算")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadExisting)
        .onChange(of: selectedMonth) { _, _ in loadExisting() }
        .sheet(isPresented: $isAddingCategoryBudget) {
            CategoryBudgetEditorView(month: selectedMonth)
        }
        .sheet(item: $editingCategoryBudget) { budget in
            CategoryBudgetEditorView(month: selectedMonth, budget: budget)
        }
    }

    private func loadExisting() {
        if let existing {
            amountText = NSDecimalNumber(decimal: Money(minorUnits: existing.amountMinor).decimalValue).stringValue
        } else {
            amountText = ""
        }
    }

    private func save() {
        guard let amount = Money(decimalString: amountText)?.minorUnits, amount > 0 else { return }
        if let existing {
            existing.amountMinor = amount
            existing.updatedAt = Date()
        } else {
            modelContext.insert(MonthlyBudget(monthStart: selectedMonth, amountMinor: amount))
        }
        do {
            try modelContext.save()
            appState.presentToast("预算已保存")
        } catch {
            appState.presentToast("预算保存失败", style: .error)
        }
    }

    private func categoryName(for budget: MonthlyBudget) -> String {
        categories.first { $0.id == budget.categoryID }?.name ?? "未知分类"
    }

    private func delete(_ budget: MonthlyBudget) {
        modelContext.delete(budget)
        do {
            try modelContext.save()
            appState.presentToast("分类预算已删除", style: .warning)
        } catch {
            modelContext.rollback()
            appState.presentToast("预算删除失败", style: .error)
        }
    }
}

private struct CategoryBudgetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \MonthlyBudget.monthStart, order: .reverse) private var budgets: [MonthlyBudget]
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]

    let month: Date
    let budget: MonthlyBudget?

    @State private var categoryID: String
    @State private var amountText: String

    private var expenseCategories: [LedgerCategory] {
        categories.filter { $0.kind == .expense }
    }

    init(month: Date, budget: MonthlyBudget? = nil) {
        self.month = month
        self.budget = budget
        _categoryID = State(initialValue: budget?.categoryID ?? "")
        _amountText = State(initialValue: budget.map {
            NSDecimalNumber(decimal: Money(minorUnits: $0.amountMinor).decimalValue).stringValue
        } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("支出分类", selection: $categoryID) {
                        Text("请选择").tag("")
                        ForEach(expenseCategories) { category in
                            Label(category.name, systemImage: category.symbol)
                                .tag(category.id)
                        }
                    }
                    .disabled(budget != nil)

                    HStack(alignment: .firstTextBaseline) {
                        Text("¥").foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2.monospacedDigit().weight(.semibold))
                    }
                } footer: {
                    Text(month.formatted(.dateTime.year().month(.wide)))
                }
            }
            .navigationTitle(budget == nil ? "添加分类预算" : "编辑分类预算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.semibold)
                        .disabled(categoryID.isEmpty || (Money(decimalString: amountText)?.minorUnits ?? 0) <= 0)
                }
            }
            .onAppear {
                if categoryID.isEmpty { categoryID = expenseCategories.first?.id ?? "" }
            }
        }
    }

    private func save() {
        guard let amount = Money(decimalString: amountText)?.minorUnits, amount > 0 else { return }
        if let budget {
            budget.amountMinor = amount
            budget.updatedAt = Date()
        } else if let existing = budgets.first(where: {
            $0.categoryID == categoryID
                && Calendar.current.isDate($0.monthStart, equalTo: month, toGranularity: .month)
        }) {
            existing.amountMinor = amount
            existing.updatedAt = Date()
        } else {
            modelContext.insert(MonthlyBudget(
                monthStart: month,
                categoryID: categoryID,
                amountMinor: amount
            ))
        }

        do {
            try modelContext.save()
            appState.presentToast("分类预算已保存")
            dismiss()
        } catch {
            modelContext.rollback()
            appState.presentToast("分类预算保存失败", style: .error)
        }
    }
}
