# Probe Chinese language capabilities and CJK fonts on Windows (CI or local).
# Usage: pwsh -File scripts/probe-windows-cjk-fonts.ps1

$ErrorActionPreference = "Continue"

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
    "Microsoft JhengHei",
    "PingFang",
    "Noto Sans CJK"
)

function Write-Section($Title) {
    Write-Host ""
    Write-Host "=== $Title ==="
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

function Install-ChineseCapabilities {
    $results = @()
    if (-not (Get-Command Get-WindowsCapability -ErrorAction SilentlyContinue)) {
        return @([PSCustomObject]@{
            Step = "Get-WindowsCapability"
            Status = "skipped"
            Detail = "Cmdlet not available on this OS"
        })
    }

    try {
        $caps = Get-WindowsCapability -Online |
            Where-Object { $_.Name -match "zh-CN|zh-Hans|Chinese" -and $_.State -ne "Installed" }
    } catch {
        return @([PSCustomObject]@{
            Step = "Get-WindowsCapability"
            Status = "error"
            Detail = $_.Exception.Message
        })
    }

    Write-Host "Available zh-CN / Chinese capabilities to install:"
    $caps | ForEach-Object { Write-Host "  $($_.Name) [$($_.State)]" }

    foreach ($cap in $caps) {
        Write-Host "Installing: $($cap.Name) ..."
        try {
            $out = Add-WindowsCapability -Online -Name $cap.Name
            $results += [PSCustomObject]@{
                Step = $cap.Name
                Status = "ok"
                Detail = "RestartNeeded=$($out.RestartNeeded)"
            }
        } catch {
            $results += [PSCustomObject]@{
                Step = $cap.Name
                Status = "error"
                Detail = $_.Exception.Message
            }
        }
    }

    if (-not $caps) {
        $results += [PSCustomObject]@{
            Step = "Add-WindowsCapability"
            Status = "skipped"
            Detail = "No pending zh-CN capabilities"
        }
    }

    return $results
}

function Install-ChineseLanguage {
    if (-not (Get-Command Install-Language -ErrorAction SilentlyContinue)) {
        return [PSCustomObject]@{
            Step = "Install-Language"
            Status = "skipped"
            Detail = "Cmdlet not available"
        }
    }

    try {
        $lang = Get-InstalledLanguage | Where-Object { $_.Language -eq "zh-Hans-CN" }
        if ($lang) {
            return [PSCustomObject]@{
                Step = "Install-Language zh-Hans-CN"
                Status = "skipped"
                Detail = "Already installed"
            }
        }
        Write-Host "Running Install-Language zh-Hans-CN ..."
        Install-Language zh-Hans-CN -CopyToSettings -ErrorAction Stop
        return [PSCustomObject]@{
            Step = "Install-Language zh-Hans-CN"
            Status = "ok"
            Detail = "Completed"
        }
    } catch {
        return [PSCustomObject]@{
            Step = "Install-Language zh-Hans-CN"
            Status = "error"
            Detail = $_.Exception.Message
        }
    }
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
    $_ -match "Hei|Sun|YaHei|Sim|黑|宋|雅|Deng|Jheng|PingFang|Noto"
} | Sort-Object | ForEach-Object { Write-Host "  $_" }

Write-Section "Install Chinese language / capabilities"
$installResults = @()
$installResults += Install-ChineseCapabilities
$installResults += Install-ChineseLanguage
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

Write-Host "msyh.ttc present:        $yaheiFile"
Write-Host "simhei.ttf present:      $simheiFile"
Write-Host "YaHei family (any):      $yaheiFamily"
Write-Host "SimHei / 黑体 family:    $simheiFamily"

$reportPath = Join-Path $PWD "probe-windows-fonts-report.txt"
@(
    "OS: $([System.Environment]::OSVersion.VersionString)",
    "msyh.ttc: $yaheiFile",
    "simhei.ttf: $simheiFile",
    "Microsoft YaHei family: $yaheiFamily",
    "SimHei family: $simheiFamily",
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
        "| Check | Result |",
        "|-------|--------|",
        "| msyh.ttc | $yaheiFile |",
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
