import SwiftUI
import PhotosUI
import SwiftData
import UIKit

struct RecognitionImportView: View {
    private enum Phase {
        case selecting
        case processing
        case review(ValidatedRecognition)
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
                case .review(let recognition):
                    RecognitionReviewView(recognition: recognition) {
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
                RoundedRectangle(cornerRadius: 30, style: .continuous)
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
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.primary.opacity(0.08)) }
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
                withAnimation(.snappy) { phase = .review(outcome.recognition) }
            } else {
                let saved = try await AppDatabase.shared.saveRecognition(
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

    let recognition: ValidatedRecognition
    let onSaved: () -> Void

    @State private var amountText: String
    @State private var merchant: String
    @State private var kind: TransactionKind
    @State private var categoryID: String
    @State private var occurredAt: Date
    @State private var note: String

    init(recognition: ValidatedRecognition, onSaved: @escaping () -> Void) {
        self.recognition = recognition
        self.onSaved = onSaved
        _amountText = State(initialValue: NSDecimalNumber(decimal: Money(minorUnits: recognition.amountMinor).decimalValue).stringValue)
        _merchant = State(initialValue: recognition.merchant)
        _kind = State(initialValue: recognition.kind)
        _categoryID = State(initialValue: recognition.categoryID)
        _occurredAt = State(initialValue: recognition.occurredAt)
        _note = State(initialValue: recognition.note ?? "")
    }

    private var matchingCategories: [LedgerCategory] {
        categories.filter { $0.kind == kind || (kind == .refund && $0.kind == .income) }
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
                    .disabled((Money(decimalString: amountText)?.minorUnits ?? 0) <= 0)
                    .accessibilityIdentifier("confirmRecognitionButton")
            }
        }
        .onChange(of: kind) { _, _ in
            if !matchingCategories.contains(where: { $0.id == categoryID }) {
                categoryID = matchingCategories.first?.id ?? "expense.other"
            }
        }
    }

    private func save() {
        guard let money = Money(decimalString: amountText), money.minorUnits > 0 else { return }
        let item = LedgerTransaction(
            kind: kind,
            amountMinor: money.minorUnits,
            merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryID: categoryID,
            occurredAt: occurredAt,
            note: note,
            source: .photoImport,
            confidence: recognition.confidence
        )
        modelContext.insert(item)
        do {
            try modelContext.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            appState.presentToast("账单已确认")
            onSaved()
        } catch {
            appState.presentToast("保存失败，请重试", style: .error)
        }
    }
}
