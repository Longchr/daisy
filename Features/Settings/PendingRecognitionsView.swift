import SwiftUI
import SwiftData

struct PendingRecognitionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecognitionDraft.createdAt, order: .reverse) private var drafts: [RecognitionDraft]
    @Query(sort: \LedgerCategory.sortOrder) private var categories: [LedgerCategory]

    private var reviewDrafts: [RecognitionDraft] {
        drafts.filter { $0.statusRaw == RecognitionDraftStatus.needsReview.rawValue }
    }

    private var failedDrafts: [RecognitionDraft] {
        drafts.filter { $0.statusRaw == RecognitionDraftStatus.failed.rawValue }
    }

    var body: some View {
        List {
            if reviewDrafts.isEmpty && failedDrafts.isEmpty {
                ContentUnavailableView("没有待确认账单", systemImage: "checkmark.circle", description: Text("低置信识别会安全地出现在这里。"))
                    .listRowBackground(Color.clear)
            }

            if !reviewDrafts.isEmpty {
                Section("待确认") {
                    ForEach(reviewDrafts) { draft in
                        if let recognition = decode(draft) {
                            NavigationLink {
                                PendingReviewContainer(draft: draft, recognition: recognition)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(recognition.merchant).font(.body.weight(.medium))
                                        Spacer()
                                        Text(Money(minorUnits: recognition.amountMinor).formatted())
                                            .font(.body.monospacedDigit().weight(.semibold))
                                    }
                                    Text("置信度 \(recognition.confidence.formatted(.percent.precision(.fractionLength(0)))) · \(draft.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Label("无法解析的识别结果", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(DaisyTheme.warning)
                        }
                    }
                    .onDelete { offsets in delete(reviewDrafts, at: offsets) }
                }
            }

            if !failedDrafts.isEmpty {
                Section {
                    ForEach(failedDrafts) { draft in
                        VStack(alignment: .leading, spacing: 5) {
                            Label(failureMessage(for: draft.errorCode), systemImage: "exclamationmark.circle")
                                .foregroundStyle(DaisyTheme.warning)
                            Text(draft.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in delete(failedDrafts, at: offsets) }
                } header: {
                    Text("失败记录")
                } footer: {
                    Text("Daisy 不保存失败截图。请回到付款页重新双击，或从相册再次选择截图。")
                }
            }
        }
        .navigationTitle("识别记录")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func decode(_ draft: RecognitionDraft) -> ValidatedRecognition? {
        guard let data = draft.transactionJSON,
              let payload = try? JSONDecoder().decode(RecognitionPayload.self, from: data) else { return nil }
        return try? RecognitionValidator.validate(
            payload,
            ocrText: "",
            allowedCategoryIDs: Set(categories.map(\.id)),
            autoSaveThreshold: 1,
            highValueThresholdMinor: .max
        )
    }

    private func delete(_ records: [RecognitionDraft], at offsets: IndexSet) {
        for index in offsets { modelContext.delete(records[index]) }
        try? modelContext.save()
    }

    private func failureMessage(for code: String?) -> String {
        switch code {
        case "invalid_url": "AI 服务尚未配置"
        case "local_network_disabled": "本地网络访问未开启"
        case "unauthorized": "API Key 无效或没有权限"
        case "rate_limited": "AI 服务请求过于频繁"
        case "model_not_found": "所选模型不存在"
        case "vision_not_supported": "模型不支持图片识别"
        case "timeout": "AI 服务响应超时"
        case "tls_failure": "AI 服务证书校验失败"
        case "image_too_large": "截图压缩后仍然过大"
        case "invalid_response": "AI 返回格式不正确"
        case "missing_amount": "未识别到可信金额"
        case "unsupported_currency": "识别到不支持的币种"
        case "image_unreadable": "截图无法读取"
        case "network": "网络连接失败"
        default: "识别未完成"
        }
    }
}

private struct PendingReviewContainer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let draft: RecognitionDraft
    let recognition: ValidatedRecognition

    var body: some View {
        RecognitionReviewView(
            recognition: recognition,
            source: .aiScreenshot,
            idempotencyKey: draft.idempotencyKey
        ) {
            modelContext.delete(draft)
            try? modelContext.save()
            dismiss()
        }
        .navigationTitle("确认识别")
        .navigationBarTitleDisplayMode(.inline)
    }
}
