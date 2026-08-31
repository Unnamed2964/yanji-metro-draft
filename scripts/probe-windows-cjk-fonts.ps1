# Probe Chinese supplemental fonts on Windows (CI or local).
# Usage: pwsh -File scripts/probe-windows-cjk-fonts.ps1
#
# Installs "Chinese (Simplified) Supplemental Fonts" capability:
#   Language.Fonts.Hans~~~und-HANS~0.0.1.0  (SimHei, DengXian, FangSong, KaiTi)

$ErrorActionPreference = "Continue"

$HansSupplementalFontsCapability = "Language.Fonts.Hans~~~und-HANS~0.0.1.0"

$TargetFontFiles = @(
    "msyh.ttc",
    "msyhbd.ttc",
    "msyhl.ttc",
    "simhei.ttf",
    "simsun.ttc",
    "simsunb.ttf",
    "msjh.ttc",
    "msjhbd.ttc",
    "Deng.ttf",
    "Dengb.ttf"
)

$TargetFamilyPatterns = @(
    "Microsoft YaHei",
    "SimHei",
    "黑体",
    "微软雅黑",
    "SimSun",
    "宋体",
    "DengXian",
    "FangSong",
    "KaiTi",
    "Microsoft JhengHei",
    "PingFang",
    "Noto Sans CJK"
)

function Write-Section($Title) {
    Write-Host ""
    Write-Host "=== $Title ==="
}

function New-StepResult($Step, $Status, $Detail, $ElapsedSec = $null) {
    [PSCustomObject]@{
        Step = $Step
        Status = $Status
        Detail = $Detail
        ElapsedSec = if ($null -ne $ElapsedSec) { [math]::Round($ElapsedSec, 1) } else { $null }
    }
}

function Get-FontFileReport {
    $fontsDir = Join-Path $env:Windir "Fonts"
    $found = @()
    $missing = @()
    foreach ($name in $TargetFontFiles) {
        $path = Join-Path $fontsDir $name
        if (Test-Path $path) {
            $item = Get-Item $path
            $found += [PSCustomObject]@{
                File = $name
                SizeKB = [math]::Round($item.Length / 1KB, 1)
            }
        } else {
            $missing += $name
        }
    }
    [PSCustomObject]@{
        Found = $found
        Missing = $missing
    }
}

function Get-FontFamilyReport {
    Add-Type -AssemblyName System.Drawing
    $families = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
    $matched = @()
    foreach ($pattern in $TargetFamilyPatterns) {
        $hits = $families | Where-Object { $_ -like "*$pattern*" }
        if ($hits) {
            $matched += [PSCustomObject]@{ Pattern = $pattern; Families = ($hits -join ", ") }
        } else {
            $matched += [PSCustomObject]@{ Pattern = $pattern; Families = "(none)" }
        }
    }
    $matched
}

function Get-FontCapabilitiesReport {
    if (-not (Get-Command Get-WindowsCapability -ErrorAction SilentlyContinue)) {
        return @()
    }
    try {
        return Get-WindowsCapability -Online -Name "*Fonts*" | ForEach-Object {
            [PSCustomObject]@{
                Name = $_.Name
                State = $_.State
                DisplayName = $_.DisplayName
                Description = $_.Description
            }
        }
    } catch {
        Write-Host "Get-WindowsCapability *Fonts* failed: $($_.Exception.Message)"
        return @()
    }
}

function Install-CapabilityIfNeeded($Name, $Label) {
    if (-not (Get-Command Add-WindowsCapability -ErrorAction SilentlyContinue)) {
        return New-StepResult $Label "skipped" "Add-WindowsCapability not available"
    }

    try {
        $cap = Get-WindowsCapability -Online -Name $Name | Select-Object -First 1
    } catch {
        return New-StepResult $Label "error" $_.Exception.Message
    }

    if (-not $cap) {
        return New-StepResult $Label "skipped" "Capability not found: $Name"
    }

    Write-Host "$Label [$($cap.State)]"
    Write-Host "  Name: $($cap.Name)"
    if ($cap.DisplayName) { Write-Host "  DisplayName: $($cap.DisplayName)" }
    if ($cap.Description) { Write-Host "  Description: $($cap.Description)" }

    if ($cap.State -eq "Installed") {
        return New-StepResult $Label "skipped" "Already installed"
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Host "Installing $Label ..."
    try {
        $out = Add-WindowsCapability -Online -Name $cap.Name
        $sw.Stop()
        return New-StepResult $Label "ok" "RestartNeeded=$($out.RestartNeeded)" $sw.Elapsed.TotalSeconds
    } catch {
        $sw.Stop()
        return New-StepResult $Label "error" $_.Exception.Message $sw.Elapsed.TotalSeconds
    }
}

function Install-SupplementalHansFonts {
    Install-CapabilityIfNeeded $HansSupplementalFontsCapability "Chinese (Simplified) Supplemental Fonts"
}

Write-Section "Environment"
Write-Host "OS: $([System.Environment]::OSVersion.VersionString)"
Write-Host "Computer: $env:COMPUTERNAME"
Write-Host "User: $env:USERNAME"
Write-Host "IsAdmin: $(([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"

Write-Section "Font files BEFORE"
$beforeFiles = Get-FontFileReport
$beforeFiles.Found | Format-Table -AutoSize
Write-Host "Missing:" ($beforeFiles.Missing -join ", ")

Write-Section "Font families BEFORE"
Get-FontFamilyReport | Format-Table -AutoSize

Write-Section "All installed families matching Hei / Sun / YaHei / Sim / 黑 / 宋 / 雅 (BEFORE)"
Add-Type -AssemblyName System.Drawing
$allFamilies = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
$allFamilies | Where-Object {
    $_ -match "Hei|Sun|YaHei|Sim|黑|宋|雅|Deng|Jheng|PingFang|Noto|FangSong|KaiTi"
} | Sort-Object | ForEach-Object { Write-Host "  $_" }

Write-Section "Font capabilities on system (*Fonts*)"
$fontCaps = Get-FontCapabilitiesReport
if ($fontCaps) {
    $fontCaps | Format-Table Name, State, DisplayName -AutoSize
} else {
    Write-Host "(none listed or cmdlet unavailable)"
}

Write-Section "Install Chinese (Simplified) Supplemental Fonts"
$installResults = @()
$installResults += Install-SupplementalHansFonts
$installResults | Format-Table -AutoSize

Write-Section "Font files AFTER (no reboot)"
$afterFiles = Get-FontFileReport
$afterFiles.Found | Format-Table -AutoSize
Write-Host "Missing:" ($afterFiles.Missing -join ", ")

Write-Section "Font families AFTER (no reboot)"
Get-FontFamilyReport | Format-Table -AutoSize

Write-Section "Summary"
$yaheiFile = Test-Path (Join-Path $env:Windir "Fonts\msyh.ttc")
$simheiFile = Test-Path (Join-Path $env:Windir "Fonts\simhei.ttf")
$familyReport = Get-FontFamilyReport
$yaheiFamily = ($familyReport | Where-Object {
    $_.Pattern -in @("Microsoft YaHei", "微软雅黑")
}).Families -notcontains "(none)"
$simheiFamily = ($familyReport | Where-Object {
    $_.Pattern -in @("SimHei", "黑体")
}).Families -notcontains "(none)"

Write-Host "msyh.ttc present:        $yaheiFile  (YaHei is NOT in Supplemental Fonts FOD)"
Write-Host "simhei.ttf present:      $simheiFile  (expected from Supplemental Fonts FOD)"
Write-Host "YaHei family (any):      $yaheiFamily"
Write-Host "SimHei / 黑体 family:    $simheiFamily"

$reportPath = Join-Path $PWD "probe-windows-fonts-report.txt"
@(
    "OS: $([System.Environment]::OSVersion.VersionString)",
    "Hans supplemental capability: $HansSupplementalFontsCapability",
    "msyh.ttc: $yaheiFile",
    "simhei.ttf: $simheiFile",
    "YaHei family: $yaheiFamily",
    "SimHei / 黑体 family: $simheiFamily",
    "",
    "Install results:",
    ($installResults | Format-Table -AutoSize | Out-String),
    "",
    "Font files after:",
    ($afterFiles.Found | Format-Table -AutoSize | Out-String)
) | Set-Content -Path $reportPath -Encoding UTF8

Write-Host "Report written to: $reportPath"

if ($env:GITHUB_STEP_SUMMARY) {
    $summary = @(
        "## Windows CJK font probe",
        "",
        "Install: **Chinese (Simplified) Supplemental Fonts** (`Language.Fonts.Hans~~~und-HANS~0.0.1.0`) — SimHei, DengXian, FangSong, KaiTi.",
        "",
        "| Check | Result |",
        "|-------|--------|",
        "| msyh.ttc (YaHei) | $yaheiFile |",
        "| simhei.ttf | $simheiFile |",
        "| YaHei family | $yaheiFamily |",
        "| SimHei / 黑体 family | $simheiFamily |",
        "",
        "### Install steps",
        "",
        ($installResults | Format-Table -AutoSize | Out-String),
        "### Font files after (no reboot)",
        "",
        ($afterFiles.Found | Format-Table -AutoSize | Out-String)
    ) -join "`n"
    $summary | Out-File -FilePath $env:GITHUB_STEP_SUMMARY -Encoding utf8 -Append
}
