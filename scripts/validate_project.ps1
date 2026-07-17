$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$required = @(
    'project.yml',
    'Resources\Info.plist',
    'Resources\Assets.xcassets\Contents.json',
    'Resources\Assets.xcassets\AppIcon.appiconset\DaisyAppIcon.png',
    'App\DaisyApp.swift',
    'App\RootView.swift',
    'Services\OpenAICompatibleClient.swift',
    'Intents\RecognizePaymentIntent.swift',
    'DaisyTests\RecognitionValidatorTests.swift',
    'DaisyUITests\DaisyUITests.swift'
)

foreach ($relative in $required) {
    $path = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required file: $relative"
    }
}

$jsonFiles = Get-ChildItem -Path (Join-Path $root 'Resources\Assets.xcassets') -Filter '*.json' -Recurse
foreach ($file in $jsonFiles) {
    $null = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName | ConvertFrom-Json
}

$plistPath = Join-Path $root 'Resources\Info.plist'
[xml]$plist = Get-Content -Raw -Encoding UTF8 -LiteralPath $plistPath
if ($plist.plist.dict -eq $null) { throw 'Info.plist is not a valid property list document.' }

$projectYAML = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root 'project.yml')
if ($projectYAML.Contains("`t")) { throw 'project.yml contains tabs.' }
if ($projectYAML -notmatch 'PRODUCT_BUNDLE_IDENTIFIER: com\.daisy\.personal\.app') {
    throw 'Unexpected bundle identifier.'
}

$sourceFiles = Get-ChildItem -Path $root -Filter '*.swift' -Recurse | Where-Object {
    $_.FullName -notmatch '\\DerivedData\\|\\build\\'
}
if ($sourceFiles.Count -lt 20) { throw "Expected at least 20 Swift files, found $($sourceFiles.Count)." }

$productFiles = @('README.md', 'docs\PRD.md', 'Resources\Info.plist')
foreach ($relative in $productFiles) {
    $text = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $root $relative)
    if ($text -notmatch 'Daisy') { throw "Product name missing from $relative" }
}

$sourceSecrets = Get-ChildItem -Path $root -Filter '*.swift' -Recurse | Select-String -Pattern 'sk-[A-Za-z0-9_-]{16,}'
if ($sourceSecrets) { throw 'A possible API key is present in Swift source.' }

$icon = Get-Item -LiteralPath (Join-Path $root 'Resources\Assets.xcassets\AppIcon.appiconset\DaisyAppIcon.png')
if ($icon.Length -lt 10000) { throw 'App icon is unexpectedly small.' }

$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    & $node.Source (Join-Path $root 'scripts\swift_sanity.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'Swift structural sanity check failed.' }
}

Write-Host "Daisy repository validation passed: $($sourceFiles.Count) Swift files, $($jsonFiles.Count) asset manifests."
