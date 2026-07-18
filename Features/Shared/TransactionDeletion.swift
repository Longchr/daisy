import SwiftData

@MainActor
enum TransactionDeletion {
    @discardableResult
    static func delete(
        _ transaction: LedgerTransaction,
        in modelContext: ModelContext,
        appState: AppState
    ) -> Bool {
        let snapshot = LedgerTransactionSnapshot(transaction)
        modelContext.delete(transaction)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            appState.presentToast("删除失败，请重试", style: .error)
            return false
        }

        appState.presentToast(
            "账单已删除",
            style: .warning,
            actionTitle: "撤销"
        ) {
            restore(snapshot, in: modelContext, appState: appState)
        }
        return true
    }

    private static func restore(
        _ snapshot: LedgerTransactionSnapshot,
        in modelContext: ModelContext,
        appState: AppState
    ) {
        let restored = snapshot.makeTransaction()
        modelContext.insert(restored)

        do {
            try modelContext.save()
            appState.presentToast("账单已恢复")
        } catch {
            modelContext.rollback()
            appState.presentToast("恢复失败，请重试", style: .error)
        }
    }
}
