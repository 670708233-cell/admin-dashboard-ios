<#
.SYNOPSIS
    一键流程：触发 GitHub Actions → 下载 unsigned IPA → Sideloadly 安装到 iPhone
.PARAMETER AppleID
    免费 Apple ID 邮箱（@icloud.com / @gmail.com 等均可）
.PARAMETER AppPassword
    Apple ID 的"应用专用密码"（16位，格式 xxxx-xxxx-xxxx-xxxx）
    获取方式：https://appleid.apple.com/account/manage → 登录与安全 → 应用专用密码
.PARAMETER DeviceIP
    iPhone 的局域网 IP（如 192.168.1.100）。
    若省略则尝试通过 USB 连接（需先插线）。
.PARAMETER WorkflowRunID
    手动指定 GitHub Actions run ID（省略则拉取最新一次成功 run）。
.PARAMETER SkipDownload
    跳过 GitHub 下载，直接使用本地 IPA 文件路径。
.PARAMETER IPAPath
    本地 .ipa 文件路径（配合 SkipDownload 使用）。
.PARAMETER QuitAfterInstall
    安装完成后自动关闭 Sideloadly 窗口。
.EXAMPLE
    # 默认：自动拉取最新 CI 产物，用免费 Apple ID 安装
    .\sideload.ps1 -AppleID "myemail@gmail.com" -AppPassword "abcd-efgh-ijkl-mnop"

    # 指定本地 IPA，跳过 CI 下载
    .\sideload.ps1 -SkipDownload -IPAPath "C:\Users\Administrator\Downloads\AdminDashboard-unsigned.ipa" -AppleID "myemail@gmail.com" -AppPassword "abcd-efgh-ijkl-mnop"

    # 指定设备 IP（USB 连接时省略）
    .\sideload.ps1 -AppleID "myemail@gmail.com" -AppPassword "abcd-efgh-ijkl-mnop" -DeviceIP "192.168.1.100"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$AppleID,

    [Parameter(Mandatory = $true)]
    [string]$AppPassword,

    [string]$DeviceIP = "",

    [string]$WorkflowRunID = "",

    [switch]$SkipDownload,

    [string]$IPAPath = "",

    [switch]$QuitAfterInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ErrorLog = "$env:TEMP\sideload-error.log"
$DownloadDir = "$env:TEMP\sideload-download"

function Write-Step { param([string]$Msg) Write-Host "`n[STEP] $Msg" -ForegroundColor Cyan }
function Write-Err  { param([string]$Msg) Write-Host "ERROR: $Msg" -ForegroundColor Red }
function Test-Sideloadly {
    $paths = @(
        "${env:ProgramFiles}\Sideloadly\sideloadly.exe",
        "${env:ProgramFiles(x86)}\Sideloadly\sideloadly.exe",
        "${env:LOCALAPPDATA}\Sideloadly\sideloadly.exe",
        "$env:USERPROFILE\Downloads\s Sideloading\sideloadly.exe"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }
    # 尝试通过 where 找到
    $w = Get-Command sideloadly -ErrorAction SilentlyContinue
    if ($w) { return $w.Source }
    return $null
}

# ── 前置检查 ───────────────────────────────────────────────
Write-Step "前置检查"

$sl = Test-Sideloadly
if (-not $sl) {
    Write-Err "未检测到 Sideloadly。请先下载安装：https://sideloadly.io/"
    Write-Host "`n[提示] 下载后重新运行本脚本" -ForegroundColor Yellow
    exit 1
}
Write-Host "  Sideloadly: $sl" -ForegroundColor Green

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
    Write-Err "未检测到 Node.js。Sideloadly 需要 Node.js >= 18。"
    exit 1
}
Write-Host "  Node.js: $(node --version 2>$null)" -ForegroundColor Green

# ── 确定 IPA 来源 ───────────────────────────────────────────
$ipaFile = ""

if ($SkipDownload) {
    if (-not $IPAPath -or -not (Test-Path $IPAPath)) {
        Write-Err "请提供有效的 -IPAPath 参数，或去掉 -SkipDownload 让脚本自动下载。"
        exit 1
    }
    $ipaFile = $IPAPath
    Write-Step "使用本地 IPA: $ipaFile"
} else {
    Write-Step "从 GitHub Actions 下载 unsigned IPA"
    New-Item -ItemType Directory -Force -Path $DownloadDir | Out-Null

    # 获取 repo owner/repo（从 git remote 或默认值）
    try {
        $remote = git -C $PSScriptRoot remote get-url origin 2>&1
        if ($remote -match 'github\.com[:/]([^/]+)/([^/.]+)') {
            $owner = $matches[1]
            $repo  = $matches[2].Replace('.git', '')
        } else {
            throw "无法解析 repo 信息"
        }
    } catch {
        Write-Err "无法从 git remote 获取仓库地址。请确保仓库已 git init 并 add remote origin。"
        exit 1
    }
    Write-Host "  Repo: $owner/$repo" -ForegroundColor Green

    # 用 gh CLI 获取最新成功 run ID
    if (-not $WorkflowRunID) {
        Write-Host "  查询 GitHub Actions 最新成功 run..." -ForegroundColor Yellow
        $ghOut = gh run list --repo "$owner/$repo" --workflow "iOS Build (Unsigned IPA)" --status success --limit 1 --json databaseId --jq '.[0].databaseId' 2>&1
        if (-not $ghOut -or $ghOut -eq "null") {
            Write-Err "未找到成功的 workflow run。请先在 GitHub 触发一次构建：https://github.com/$owner/$repo/actions"
            exit 1
        }
        $WorkflowRunID = $ghOut.Trim()
        Write-Host "  Run ID: $WorkflowRunID" -ForegroundColor Green
    }

    # 下载 artifact
    $artifactFile = Join-Path $DownloadDir "AdminDashboard-unsigned.ipa"
    Write-Host "  下载 artifact..." -ForegroundColor Yellow
    gh run download "$WorkflowRunID" --repo "$owner/$repo" --name AdminDashboard-unsigned --dir $DownloadDir 2>&1 | Out-Null

    if (-not (Test-Path $artifactFile)) {
        Write-Err "下载失败，artifact 文件不存在: $artifactFile"
        exit 1
    }
    $ipaFile = $artifactFile
    Write-Host "  已下载到: $ipaFile" -ForegroundColor Green
}

# ── 启动 Sideloadly ─────────────────────────────────────────
Write-Step "启动 Sideloadly 安装..."

$slDir = Split-Path $sl -Parent

# Sideloadly CLI 参数（异步启动，等待端口就绪后发命令）
$arguments = @(
    "--ip", $DeviceIP,
    "--ipa", $ipaFile,
    "--apple-id", $AppleID,
    "--app-password", $AppPassword,
    "--quit-after-install", $QuitAfterInstall.IsPresent.ToString().ToLower()
)

# 启动 Sideloadly（无头模式安装）
$proc = Start-Process -FilePath $sl -ArgumentList $arguments -PassThru -WindowStyle Hidden
Write-Host "  Sideloadly PID: $($proc.Id)" -ForegroundColor Green
Write-Host "  请稍候，安装通常需要 30-90 秒..." -ForegroundColor Yellow

# 等待 Sideloadly 完成
Wait-Process -Id $proc.Id -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# ── 验证结果 ───────────────────────────────────────────────
Write-Step "安装完成"

# 检查是否有错误日志
if (Test-Path $ErrorLog) {
    $errContent = Get-Content $ErrorLog -Raw
    if ($errContent -and $errContent.Length -gt 0) {
        Write-Err "Sideloadly 报错:`n$errContent"
    }
}

Write-Host @"

✅ 安装完成！请检查 iPhone 上是否出现「抖数君后台」图标。
"@ -ForegroundColor Green

Write-Host @"

╔══════════════════════════════════════════════════╗
║  7天有效期提醒                                       ║
║  免费 Apple ID 签名的 App 每 7 天过期一次            ║
║                                                     ║
║  过期后重新运行此脚本即可续期（无需重新下载 IPA）      ║
║  续期命令：                                           ║
║    .\sideload.ps1 -AppleID "<ID>" -AppPassword "<PWD>" ║
╚══════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
