$ErrorActionPreference = 'Stop'

Write-Host '=== Weather Zheer - Android setup ===' -ForegroundColor Cyan

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter was not found in PATH. Install Flutter and reopen PowerShell.'
}

Write-Host '1) Generating Android platform files without touching lib/ or assets...' -ForegroundColor Yellow
flutter create --platforms=android .

$manifest = Join-Path $PWD 'android\app\src\main\AndroidManifest.xml'
if (-not (Test-Path $manifest)) { throw "AndroidManifest.xml was not created: $manifest" }

[xml]$xml = Get-Content $manifest -Raw
$ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
$ns.AddNamespace('android','http://schemas.android.com/apk/res/android')
$manifestNode = $xml.manifest

function Add-Permission([string]$name) {
  $existing = $manifestNode.SelectSingleNode("android:uses-permission[@android:name='$name']", $ns)
  if (-not $existing) {
    $node = $xml.CreateElement('uses-permission')
    $attr = $xml.CreateAttribute('android','name','http://schemas.android.com/apk/res/android')
    $attr.Value = $name
    $node.Attributes.Append($attr) | Out-Null
    $manifestNode.AppendChild($node) | Out-Null
  }
}

Add-Permission 'android.permission.INTERNET'
Add-Permission 'android.permission.ACCESS_COARSE_LOCATION'
Add-Permission 'android.permission.ACCESS_FINE_LOCATION'

# Keep HTTPS-only networking explicit. This does not disable normal HTTPS API access.
$application = $manifestNode.SelectSingleNode('android:application', $ns)
if ($application) {
  $usesCleartext = $application.GetAttributeNode('usesCleartextTraffic','http://schemas.android.com/apk/res/android')
  if (-not $usesCleartext) {
    $attr = $xml.CreateAttribute('android','usesCleartextTraffic','http://schemas.android.com/apk/res/android')
    $attr.Value = 'false'
    $application.Attributes.Append($attr) | Out-Null
  } else {
    $usesCleartext.Value = 'false'
  }
}

$settings = New-Object System.Xml.XmlWriterSettings
$settings.Indent = $true
$settings.Encoding = New-Object System.Text.UTF8Encoding($false)
$settings.OmitXmlDeclaration = $false
$writer = [System.Xml.XmlWriter]::Create($manifest, $settings)
$xml.Save($writer)
$writer.Dispose()

Write-Host '2) Getting packages...' -ForegroundColor Yellow
flutter pub get

Write-Host '3) Checking Dart code...' -ForegroundColor Yellow
flutter analyze

Write-Host '4) Building release APK...' -ForegroundColor Yellow
flutter build apk --release

Write-Host ''
Write-Host 'DONE.' -ForegroundColor Green
Write-Host 'APK: build\app\outputs\flutter-apk\app-release.apk' -ForegroundColor Green
