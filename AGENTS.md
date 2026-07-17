# Daisy repository guidance

## Product constraints

- Keep the product name `Daisy` in user-facing copy, schemes, assets, and documentation.
- Target iPhone on iOS 17 or later with native SwiftUI, SwiftData, App Intents, Vision, and Charts.
- Do not introduce paid Apple capabilities, a product-owned backend, analytics SDKs, or third-party UI frameworks.
- AI access is direct OpenAI-compatible access configured at runtime. Never commit API keys or real financial data.
- Keep App Intent in the main app target so free signing uses as few App IDs as possible.

## UI expectations

- Prefer native NavigationStack, List, Form, Sheet, Menu, system materials, SF Symbols, Dynamic Type, VoiceOver, and semantic colors.
- Avoid Android-like floating action buttons, custom bottom navigation, oversized gradients, or non-native form controls.
- Preserve dark mode, Reduce Motion, amount privacy, 44-point hit targets, and monospaced financial figures.

## Build and verification

On macOS:

```bash
xcodegen generate
xcodebuild test -project Daisy.xcodeproj -scheme Daisy -destination 'platform=iOS Simulator,id=<device-id>' CODE_SIGNING_ALLOWED=NO
```

On Windows:

```powershell
./scripts/validate_project.ps1
```

CI is authoritative for Apple-framework compilation. Do not claim delivery readiness until the macOS CI build and tests pass and the resulting IPA is verified on the target iPhone.
