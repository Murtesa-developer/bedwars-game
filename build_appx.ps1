<#
  Builds build\BedWars_x86.appx (Windows 10 / 11, x86) from this Godot project.

  Requirements (Windows):
    - Godot 4.x STANDARD editor (not .NET) + matching export templates (Editor > Manage Export Templates)
    - Windows 10/11 SDK (makeappx.exe, signtool.exe)

  Usage (PowerShell, inside the project folder):
    .\build_appx.ps1
    .\build_appx.ps1 -Godot "C:\Tools\Godot_v4.7.2-stable_win64.exe"
    .\build_appx.ps1 -SelfSign        # also sign it for a local test install
#>
param(
  [string]$Godot = "",
  [string]$SdkBin = "",
  [switch]$SelfSign
)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

# ---- find Godot
if (-not $Godot) {
  $dirs = @($root, (Split-Path $root -Parent), "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop", "C:\Godot", "C:\Tools", "$env:ProgramFiles\Godot")
  foreach ($d in $dirs) {
    if (Test-Path $d) {
      $f = Get-ChildItem $d -Filter "Godot*.exe" -Recurse -Depth 2 -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike "*mono*" -and $_.Name -notlike "*console*" } | Select-Object -First 1
      if ($f) { $Godot = $f.FullName; break }
    }
  }
}
if (-not $Godot) { $Godot = (Read-Host "Path to Godot exe (drag the file here)").Trim('"') }
if (-not (Test-Path $Godot)) { throw "Godot not found at: $Godot" }
# prefer the console exe sitting next to it: it behaves like a normal command line program
$console = $Godot -replace '\.exe$', '_console.exe'
if (Test-Path $console) { $Godot = $console }
Write-Host "Using Godot: $Godot"

# ---- check the x86 export template exists
$tpl = $null
$tplRoots = @((Join-Path $env:APPDATA "Godot\export_templates"), (Join-Path (Split-Path $Godot -Parent) "editor_data\export_templates"))
foreach ($tr in $tplRoots) {
  if (-not $tpl -and (Test-Path $tr)) { $tpl = Get-ChildItem $tr -Recurse -Filter "windows_release_x86_32.exe" -ErrorAction SilentlyContinue | Select-Object -First 1 }
}
if (-not $tpl) {
  throw "Export templates not found (windows_release_x86_32.exe). Open the Godot editor > Editor menu > Manage Export Templates > Download and Install (or Install from File with the .tpz from godotengine.org), then run this script again. Looked in: $($tplRoots -join ', ')"
}
Write-Host "Export template: $($tpl.FullName)"

$pkg  = Join-Path $root "build\pkg"
$out  = Join-Path $root "build\BedWars_x86.appx"
$log  = Join-Path $root "build\godot_export.log"
if (Test-Path $pkg) { Remove-Item $pkg -Recurse -Force }
New-Item -ItemType Directory -Force -Path $pkg | Out-Null

function Run-Godot([string[]]$GodotArgs) {
  $o = Join-Path $root "build\godot_out.txt"; $e = Join-Path $root "build\godot_err.txt"
  $p = Start-Process -FilePath $Godot -ArgumentList $GodotArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput $o -RedirectStandardError $e
  $text = (Get-Content $o -ErrorAction SilentlyContinue) + (Get-Content $e -ErrorAction SilentlyContinue)
  Add-Content $log ("> godot " + ($GodotArgs -join " "))
  Add-Content $log $text
  return @{ Code = $p.ExitCode; Text = $text }
}
if (Test-Path $log) { Remove-Item $log -Force }

# ---- import, then export a RELEASE x86 build
Write-Host "Importing project resources..."
$null = Run-Godot @("--headless", "--path", "`"$root`"", "--import")
Write-Host "Exporting x86 release build..."
$exe = Join-Path $pkg "BedWars.exe"
$r = Run-Godot @("--headless", "--path", "`"$root`"", "--export-release", "`"Windows Desktop`"", "`"$exe`"")
if (-not (Test-Path $exe)) {
  Write-Host "---- Godot said: ----" -ForegroundColor Yellow
  $r.Text | Select-Object -Last 40 | ForEach-Object { Write-Host $_ }
  Write-Host "(full log: $log)" -ForegroundColor Yellow
  throw "Godot export failed - BedWars.exe was not created. Send the text above to get it fixed."
}
Write-Host "Exported: $exe"

# ---- manifest + assets
Copy-Item (Join-Path $root "appx\AppxManifest.xml") $pkg
Copy-Item (Join-Path $root "appx\Assets") (Join-Path $pkg "Assets") -Recurse

# ---- makeappx / signtool (search PATH, then every drive's Windows Kits folder)
$bin = $null
if ($SdkBin) {
  if (Test-Path (Join-Path $SdkBin "makeappx.exe")) { $bin = $SdkBin } else { throw "makeappx.exe is not in the -SdkBin folder: $SdkBin" }
}
$cmd = Get-Command makeappx.exe -ErrorAction SilentlyContinue
if ($cmd -and -not $bin) { $bin = Split-Path $cmd.Source -Parent }
if (-not $bin) {
  $roots = @()
  foreach ($d in (Get-PSDrive -PSProvider FileSystem)) {
    $roots += (Join-Path $d.Root "Program Files (x86)\Windows Kits\10\bin")
    $roots += (Join-Path $d.Root "Program Files\Windows Kits\10\bin")
    $roots += (Join-Path $d.Root "Windows Kits\10\bin")
  }
  $roots += "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
  foreach ($r in ($roots | Select-Object -Unique)) {
    if (-not $bin -and (Test-Path $r)) {
      $hit = Get-ChildItem $r -Recurse -Filter makeappx.exe -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Where-Object { $_.FullName -match "\\(x86|x64)\\" } | Select-Object -First 1
      if ($hit) { $bin = $hit.DirectoryName }
    }
  }
}
if (-not $bin) {
  throw "makeappx.exe not found. Install the Windows SDK: run  winget install Microsoft.WindowsSDK.10.0.26100  (or download 'Windows SDK' from developer.microsoft.com/windows/downloads/windows-sdk), tick 'Windows SDK Signing Tools for Desktop Apps' and 'MSIX Packaging Tools' if asked, then run this script again."
}
Write-Host "Using SDK tools: $bin"

if (Test-Path $out) { Remove-Item $out -Force }
& (Join-Path $bin "makeappx.exe") pack /d $pkg /p $out /o
if ($LASTEXITCODE -ne 0) { throw "makeappx failed (see messages above - usually a CHANGE-ME value or a missing asset in AppxManifest.xml)" }
Write-Host "Created $out" -ForegroundColor Green

if ($SelfSign) {
  $manifest = [xml](Get-Content (Join-Path $pkg "AppxManifest.xml"))
  $subject  = $manifest.Package.Identity.Publisher
  $cert = New-SelfSignedCertificate -Type Custom -Subject $subject -KeyUsage DigitalSignature -FriendlyName "BedWars Dev" `
          -CertStoreLocation "Cert:\CurrentUser\My" -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3", "2.5.29.19={text}")
  $pfx = Join-Path $root "build\BedWarsDev.pfx"
  $pw  = ConvertTo-SecureString "bedwars" -AsPlainText -Force
  Export-PfxCertificate -Cert $cert -FilePath $pfx -Password $pw | Out-Null
  Export-Certificate -Cert $cert -FilePath (Join-Path $root "build\BedWarsDev.cer") | Out-Null
  & (Join-Path $bin "signtool.exe") sign /fd SHA256 /a /f $pfx /p bedwars $out
  Write-Host "Signed. To install locally: import build\BedWarsDev.cer into 'Trusted People' (as admin), then double-click the .appx"
}
