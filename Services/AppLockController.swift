import Foundation
import LocalAuthentication
import Combine

@MainActor
final class AppLockController: ObservableObject {
    @Published private(set) var isUnlocked: Bool
    @Published private(set) var errorMessage: String?

    init(initiallyUnlocked: Bool = true) {
        self.isUnlocked = initiallyUnlocked
    }

    func lock() {
        isUnlocked = false
    }

    func unlock() async {
        let context = LAContext()
        context.localizedCancelTitle = "取消"
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            errorMessage = "设备未设置可用的身份验证"
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "解锁 Daisy 并查看本地账本"
            )
            isUnlocked = success
            errorMessage = nil
        } catch {
            errorMessage = "未能完成身份验证"
        }
    }

    static var unlockedPreview: AppLockController {
        AppLockController(initiallyUnlocked: true)
    }
}
