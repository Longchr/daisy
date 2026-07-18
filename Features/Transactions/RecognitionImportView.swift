import SwiftUI
import PhotosUI
import SwiftData
import UIKit

struct RecognitionImportView: View {
    private enum Phase {
        case selecting
        case processing
        case review(ValidatedRecognition, String)
        case failed(String)
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var selectedItem: PhotosPickerItem?
    @State private var phase: Phase = .selecting
    @State private var previewImage: UIImage?

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .selecting:
                    selectionView
                case .processing:
                    processingView
                case .review(let recognition, let idempotencyKey):
                    RecognitionReviewView(
                        recognition: recognition,
                        source: .photoImport,
                        idempotencyKey: idempotencyKey
                    ) {
                        dismiss()
                    }
                case .failed(let message):
                    ContentUnavailableView {
                        Label("识别未完成", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("重新选择") {
                            withAnimation(.snappy) { phase = .selecting }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("识别付款截图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task { await recognize(item) }
        }
    }

    private var selectionView: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DaisyTheme.accent.opacity(0.11))
                    .frame(width: 122, height: 122)
                Image(systemName: "viewfinder.circle.fill")
                    .font(.system(size: 58, weight: .medium))
                    .foregroundStyle(DaisyTheme.accent)
            }

            VStack(spacing: 9) {
                Text("选择付款成功页面")
                    .font(.title2.bold())
                Text("Daisy 会先在本地提取文字，再把压缩后的图片直接发送给你配置的 AI 服务。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("从相册选择", systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                    .frame(maxWidth: 260)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
            .tint(DaisyTheme.accent)
            .accessibilityIdentifier("photoPickerButton")

            Text("截图不会保存到 Daisy；处理结束后只保留结构化账单。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
            Spacer()
        }
    }

    private var processingView: some View {
        VStack(spacing: 22) {
            Spacer()
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 310)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.primary.opacity(0.08)) }
                    .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
            }
            ProgressView()
                .controlSize(.large)
                .tint(DaisyTheme.accent)
            VStack(spacing: 5) {
                Text("正在理解这笔交易")
                    .font(.headline)
                Text("本地 OCR · AI 提取 · 安全校验")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(24)
    }

    @MainActor
    private func recognize(_ item: PhotosPickerItem) async {
        phase = .processing
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw RecognitionError.imageUnreadable
            }
            previewImage = UIImage(data: data)
            let outcome = try await RecognitionEngine.shared.recognize(imageData: data)
            if outcome.recognition.needsReview {
                withAnimation(.snappy) {
                    phase = .review(outcome.recognition, outcome.idempotencyKey)
                }
            } else {
                let saved = try AppDatabase.shared.saveRecognition(
                    outcome.recognition,
                    idempotencyKey: outcome.idempotencyKey
                )
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                appState.presentToast("已记下 \(saved.money.formatted())")
                dismiss()
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation(.snappy) { phase = .failed(message) }
        }
    }
}

struct RecognitionReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \LedgerTransaction.occurredAt, order: .reverse) private var transactions: [LedgerTransaction]

    let recognition: ValidatedRecognition
    let source: TransactionSource
    let idempotencyKey: String?
    let onSaved: () -> Void

    @State private var amountText: String
    @State private var merchant: String
    @State private var kind: TransactionKind
    @State private var categoryID: String
    @State private var selectedAccountID: UUID?
    @State private var selectedDestinationAccountID: UUID?
    @State private var occurredAt: Date
    @State private var note: String

    init(
        recognition: ValidatedRecognition,
        source: TransactionSource = .photoImport,
        idempotencyKey: String? = nil,
        onSaved: @escaping () -> Void
    ) {
        self.recognition = recognition
        self.source = source
        self.idempotencyKey = idempotencyKey
        self.onSaved = onSaved
        _amountText = State(initialValue: NSDecimalNumber(decimal: Money(minorUnits: recognition.amountMinor).decimalValue).stringValue)
        _merchant = State(initialValue: recognition.merchant)
        _kind = State(initialValue: recognition.kind)
        _categoryID = State(initialValue: recognition.categoryID)
        _selectedAccountID = State(initialValue: nil)
        _selectedDestinationAccountID = State(initialValue: nil)
        _occurredAt = State(initialValue: recognition.occurredAt)
        _note = State(initialValue: recognition.note ?? "")
    }

    private var matchingCategories: [LedgerCategory] {
        categories.filter { $0.kind == kind || (kind == .refund && $0.kind == .income) }
    }

    private var activeAccounts: [Account] { accounts.filter { !$0.isArchived } }

    private var canSave: Bool {
        guard (Money(decimalString: amountText)?.minorUnits ?? 0) > 0 else { return false }
        guard !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !categoryID.isEmpty else { return false }
        guard kind == .transfer else { return true }
        return selectedAccountID != nil
            && selectedDestinationAccountID != nil
            && selectedAccountID != selectedDestinationAccountID
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(DaisyTheme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("需要你确认")
                            .font(.headline)
                        Text("AI 置信度 \(recognition.confidence.formatted(.percent.precision(.fractionLength(0))))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("交易") {
                Picker("类型", selection: $kind) {
                    ForEach(TransactionKind.allCases) { Text($0.title).tag($0) }
                }
                TextField("金额", text: $amountText)
                    .keyboardType(.decimalPad)
                TextField("商户", text: $merchant)
                Picker("分类", selection: $categoryID) {
                    ForEach(matchingCategories) { category in
                        Label(category.name, systemImage: category.symbol).tag(category.id)
                    }
                }
                Picker("账户", selection: $selectedAccountID) {
                    Text("未指定").tag(Optional<UUID>.none)
                    ForEach(activeAccounts) { account in
                        Label(account.name, systemImage: account.symbol)
                            .tag(Optional(account.id))
                    }
                }
                if kind == .transfer {
                    Picker("转入账户", selection: $selectedDestinationAccountID) {
                        Text("请选择").tag(Optional<UUID>.none)
                        ForEach(activeAccounts.filter { $0.id != selectedAccountID }) { account in
                            Label(account.name, systemImage: account.symbol)
                                .tag(Optional(account.id))
                        }
                    }
                }
                DatePicker("时间", selection: $occurredAt)
                TextField("备注", text: $note, axis: .vertical)
            }

            if !recognition.warnings.isEmpty {
                Section("需要确认的原因") {
                    ForEach(recognition.warnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.circle")
                            .foregroundStyle(DaisyTheme.warning)
                    }
                }
            }

            Section {
                Button("确认并保存", action: save)
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                    .accessibilityIdentifier("confirmRecognitionButton")
            }
        }
        .onAppear(perform: selectDefaultAccounts)
        .onChange(of: kind) { _, _ in
            if !matchingCategories.contains(where: { $0.id == categoryID }) {
                categoryID = matchingCategories.first?.id ?? "expense.other"
            }
            selectDefaultAccounts()
        }
        .onChange(of: selectedAccountID) { _, _ in
            if kind == .transfer { selectDefaultDestinationAccount() }
        }
    }

    private func selectDefaultAccounts() {
        if selectedAccountID == nil {
            selectedAccountID = AccountResolver.resolveID(
                accounts: activeAccounts,
                paymentChannel: recognition.paymentChannel,
                paymentMethodHint: recognition.paymentMethodHint
            )
        }
        selectDefaultDestinationAccount()
    }

    private func selectDefaultDestinationAccount() {
        guard kind == .transfer else {
            selectedDestinationAccountID = nil
            return
        }
        if selectedDestinationAccountID == nil
            || selectedDestinationAccountID == selectedAccountID
            || activeAccounts.contains(where: { $0.id == selectedDestinationAccountID }) == false {
            selectedDestinationAccountID = activeAccounts.first { $0.id != selectedAccountID }?.id
        }
    }

    private func save() {
        guard let money = Money(decimalString: amountText), money.minorUnits > 0 else { return }
        if let idempotencyKey,
           transactions.contains(where: { $0.idempotencyKey == idempotencyKey }) {
            appState.presentToast("这张截图已经记过账")
            onSaved()
            return
        }
        let item = LedgerTransaction(
            kind: kind,
            amountMinor: money.minorUnits,
            merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryID: categoryID,
            accountID: selectedAccountID,
            destinationAccountID: kind == .transfer ? selectedDestinationAccountID : nil,
            occurredAt: occurredAt,
            note: note,
            source: source,
            confidence: recognition.confidence,
            idempotencyKey: idempotencyKey
        )
        modelContext.insert(item)
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            appState.presentToast("账单已确认")
            onSaved()
        } catch {
            modelContext.rollback()
            appState.presentToast("保存失败，请重试", style: .error)
        }
    }
}
