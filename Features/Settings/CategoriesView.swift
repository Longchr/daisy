import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]
    @Query private var transactions: [LedgerTransaction]
    @Query private var budgets: [MonthlyBudget]
    @Query private var recurringReminders: [RecurringReminder]
    @State private var isAdding = false
    @State private var editingCategory: LedgerCategory?

    var body: some View {
        List {
            ForEach(TransactionKind.allCases) { kind in
                let items = categories.filter { $0.kind == kind }
                if !items.isEmpty {
                    Section(kind.title) {
                        ForEach(items) { category in
                            HStack(spacing: 12) {
                                CategoryIcon(symbol: category.symbol, tint: Color(hex: category.tintHex), size: 38)
                                Text(category.name)
                                Spacer()
                                if category.isSystem {
                                    Text("系统")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .swipeActions {
                                if !category.isSystem {
                                    Button {
                                        editingCategory = category
                                    } label: {
                                        Label("编辑", systemImage: "pencil")
                                    }
                                    .tint(DaisyTheme.accent)

                                    Button(role: .destructive) {
                                        delete(category)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("分类")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isAdding = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $isAdding) {
            CategoryEditorView()
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditorView(category: category)
        }
    }

    private func delete(_ category: LedgerCategory) {
        let isInUse = transactions.contains(where: { $0.categoryID == category.id })
            || budgets.contains(where: { $0.categoryID == category.id })
            || recurringReminders.contains(where: { $0.categoryID == category.id })
        guard !isInUse else {
            appState.presentToast("该分类仍被账单、预算或提醒使用，不能删除", style: .warning)
            return
        }
        modelContext.delete(category)
        do {
            try modelContext.save()
            appState.presentToast("分类已删除", style: .warning)
        } catch {
            modelContext.rollback()
            appState.presentToast("分类删除失败", style: .error)
        }
    }
}

private struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]

    @State private var name = ""
    @State private var kind: TransactionKind = .expense
    @State private var symbol = "tag.fill"
    @State private var tintHex = "23766E"

    let category: LedgerCategory?

    private let symbols = ["tag.fill", "cup.and.saucer.fill", "cart.fill", "figure.walk", "gift.fill", "heart.fill", "briefcase.fill", "pawprint.fill"]
    private let colors = ["23766E", "5B8DEF", "D99058", "9F7AEA", "E17B9A", "4F8B6F", "D65A5A", "8A8A8E"]

    init(category: LedgerCategory? = nil) {
        self.category = category
        if let category {
            _name = State(initialValue: category.name)
            _kind = State(initialValue: category.kind)
            _symbol = State(initialValue: category.symbol)
            _tintHex = State(initialValue: category.tintHex)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("分类名称", text: $name)
                Picker("类型", selection: $kind) {
                    ForEach(TransactionKind.allCases) { Text($0.title).tag($0) }
                }
                .disabled(category != nil)
                Section("图标") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                        ForEach(symbols, id: \.self) { candidate in
                            Button {
                                symbol = candidate
                            } label: {
                                Image(systemName: candidate)
                                    .frame(width: 44, height: 44)
                                    .background(symbol == candidate ? DaisyTheme.accent.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section("颜色") {
                    HStack {
                        ForEach(colors, id: \.self) { candidate in
                            Button {
                                tintHex = candidate
                            } label: {
                                Circle()
                                    .fill(Color(hex: candidate))
                                    .frame(width: 30, height: 30)
                                    .overlay { if tintHex == candidate { Circle().stroke(.primary, lineWidth: 2).padding(-4) } }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle(category == nil ? "添加分类" : "编辑分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let category {
            category.name = trimmedName
            category.symbol = symbol
            category.tintHex = tintHex
        } else {
            modelContext.insert(LedgerCategory(
                id: "custom.\(UUID().uuidString.lowercased())",
                name: trimmedName,
                kind: kind,
                symbol: symbol,
                tintHex: tintHex,
                sortOrder: (categories.map(\.sortOrder).max() ?? 0) + 1,
                isSystem: false
            ))
        }
        do {
            try modelContext.save()
            appState.presentToast(category == nil ? "分类已添加" : "分类已更新")
            dismiss()
        } catch {
            modelContext.rollback()
            appState.presentToast("分类保存失败", style: .error)
        }
    }
}
