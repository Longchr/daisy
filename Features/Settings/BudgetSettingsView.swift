import SwiftUI
import SwiftData

struct BudgetSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \MonthlyBudget.monthStart, order: .reverse) private var budgets: [MonthlyBudget]

    @State private var selectedMonth = Date()
    @State private var amountText = ""

    private var existing: MonthlyBudget? {
        budgets.first {
            $0.categoryID == nil && Calendar.current.isDate($0.monthStart, equalTo: selectedMonth, toGranularity: .month)
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
        }
        .navigationTitle("月度预算")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadExisting)
        .onChange(of: selectedMonth) { _, _ in loadExisting() }
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
}
