import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]
    @State private var isAdding = false

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
            AddCategoryView()
        }
    }
}

private struct AddCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]

    @State private var name = ""
    @State private var kind: TransactionKind = .expense
    @State private var symbol = "tag.fill"
    @State private var tintHex = "23766E"

    private let symbols = ["tag.fill", "cup.and.saucer.fill", "cart.fill", "figure.walk", "gift.fill", "heart.fill", "briefcase.fill", "pawprint.fill"]
    private let colors = ["23766E", "5B8DEF", "D99058", "9F7AEA", "E17B9A", "4F8B6F", "D65A5A", "8A8A8E"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("分类名称", text: $name)
                Picker("类型", selection: $kind) {
                    ForEach(TransactionKind.allCases) { Text($0.title).tag($0) }
                }
                Section("图标") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 14) {
                        ForEach(symbols, id: \.self) { candidate in
                            Button {
                                symbol = candidate
                            } label: {
                                Image(systemName: candidate)
                                    .frame(width: 44, height: 44)
                                    .background(symbol == candidate ? DaisyTheme.accent.opacity(0.18) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
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
            .navigationTitle("添加分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        modelContext.insert(LedgerCategory(
                            id: "custom.\(UUID().uuidString.lowercased())",
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            kind: kind,
                            symbol: symbol,
                            tintHex: tintHex,
                            sortOrder: (categories.map(\.sortOrder).max() ?? 0) + 1,
                            isSystem: false
                        ))
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
