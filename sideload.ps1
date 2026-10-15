<#
.SYNOPSIS
    一键流程：触发 GitHub Actions → 下载 unsigned IPA → Sideloadly 安装到 iPhone
.PARAMETER AppleID
    免费 Apple ID 邮箱
.PARAMETER AppPassword
    Apple ID 的"应用专用密码"（16位，xxxx-xxxx-xxxx-xxxx）
    获取：https://appleid.apple.com/account/manage → 登录与安全 → 应用专用密码
.PARAMETER DeviceIP
    iPhone 局域网 IP（如 192.168.1.100）。USB 直连时省略。
.PARAMETER SkipDownload
    跳过 CI 下载，直接使用 -IPAPath 指定的本地 .ipa 文件。
.PARAMETER IPAPath
    本地 IPA 文件路径（配合 -SkipDownload 使用）。
.PARAMETER GitHubToken
    GitHub Personal Access Token（不含 gh CLI 时需要，可选）。
    可从 https://github.com/settings/tokens 获取（勾选 repo 权限）。
.PARAMETER Repo
    仓库地址，格式 owner/repo（如 doushujun/admin-dashboard-ios）。
    默认自动从 git remote 解析。
.PARAMETER RunID
    手动指定 GitHub Actions run ID（省略则拉最新一次成功 run）。
.EXAMPLE
    # 首次安装（自动从 GitHub 下载最新 IPA，无需 token）
    .\sideload.ps1 -AppleID "myemail@gmail.com" -AppPassword "abcd-efgh-ijkl-mnop"

    # 续期安装（IPA 已保留，跳过下载）
    .\sideload.ps1 -SkipDownload -IPAPath "C:\Users\Administrator\Downloads\AdminDashboard-unsigned.ipa" -AppleID "myemail@gmail.com" -AppPassword "abcd-efgh-ijkl-mnop"

    # 局域网安装（iPhone 和 PC 在同一 WiFi）
    .\sideload.ps1 -AppleID "myemail@gmail.com" -AppPassword "abcd-efgh-ijkl-mnop" -DeviceIP "192.168.1.100"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$AppleID,

    [Parameter(Mandatory = $true)]
    [string]$AppPassword,

    [string]$DeviceIP = "",

    [switch]$SkipDownload,

    [string]$IPAPath = "",

    [string]$GitHubToken = "",

    [string]$Repo = "",

    [string]$RunID = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$TempDir  = "$env:TEMP\sideload-ios"
$ErrorLog = "$env:TEMP\sideload-error.log"

function Write-Step { param([string]$Msg) Write-Host "`n[STEP] $Msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Msg) Write-Host "  ✓ $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "  ⚠ $Msg" -ForegroundColor Yellow }
function Write-Err  { param([string]$Msg) Write-Host "ERROR: $Msg" -ForegroundColor Red }

# ── 检查依赖 ───────────────────────────────────────────────
Write-Step "检查环境依赖"

# 1. Sideloadly
$slPaths = @(
    "${env:ProgramFiles}\Sideloadly\sideloadly.exe",
    "${env:ProgramFiles(x86)}\Sideloadly\sideloadly.exe",
    "${env:LOCALAPPDATA}\Sideloadly\sideloadly.exe",
    "$env:USERPROFILE\s Sideloading\s Sideloading\s Sideloading\s Sideloading.exe"
)
$slExe = $null
foreach ($p in $slPaths) {
    if (Test-Path $p) { $slExe = $p; break }
}
if (-not $slExe) {
    Write-Err "未检测到 Sideloadly。请先下载安装：https://sideloadly.io/"
    exit 1
}
Write-Ok "Sideloadly: $slExe"

# 2. Node.js（Sideloadly 需要 >= 18）
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
    Write-Err "未检测到 Node.js。请安装 Node.js 22 LTS：https://nodejs.org/"
    exit 1
}
$nodeVer = & node --version 2>$null
Write-Ok "Node.js: $nodeVer"

# 3. Git
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    Write-Err "未检测到 Git。请安装 Git：https://git-scm.com/"
    exit 1
}
Write-Ok "Git 可用"

# ── 解析仓库地址 ───────────────────────────────────────────
$owner = ""
$repo  = ""

if ($Repo) {
    if ($Repo -match '^([^/]+)/([^/]+)$') {
        $owner = $matches[1]
        $repo  = $matches[2].Replace('.git', '')
    } else {
        Write-Err "-Repo 格式错误，请使用 owner/repo 格式（如 myuser/myrepo）"
        exit 1
    }
} else {
    try {
        $remoteUrl = git -C $PSScriptRoot remote get-url origin 2>&1
        if ($remoteUrl -match 'github\.com[:/]([^/]+)/([^/.]+)') {
            $owner = $matches[1]
            $repo  = $matches[2].Replace('.git', '')
        } else {
            throw "无法解析：$remoteUrl"
        }
    } catch {
        Write-Err "无法获取仓库信息。请确保仓库已 git init 并 add remote origin，或直接使用 -Repo 参数。"
        Write-Host "示例：.\sideload.ps1 -Repo doushujun/admin-dashboard-ios ..." -ForegroundColor Yellow
        exit 1
    }
}

Write-Ok "仓库: $owner/$repo"

# ── 下载 IPA ───────────────────────────────────────────────
$ipaFile = ""

if ($SkipDownload) {
    if (-not $IPAPath -or -not (Test-Path $IPAPath)) {
        Write-Err "请提供有效的 -IPAPath 参数，或去掉 -SkipDownload 让脚本自动下载。"
        exit 1
    }
    $ipaFile = $IPAPath
    Write-Step "使用本地 IPA: $ipaFile"
    Write-Ok "文件大小: $([math]::Round((Get-Item $ipaFile).Length / 1MB, 2)) MB"
} else {
    Write-Step "从 GitHub Actions 下载 unsigned IPA"
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
    $ipaFile = Join-Path $TempDir "AdminDashboard-unsigned.ipa"

    # 确定 workflow 名称（区分大小写）
    $workflowName = "iOS Build (Unsigned IPA)"

    # 获取最新成功 run ID
    if (-not $RunID) {
        Write-Host "  查询最新成功构建..." -ForegroundColor Yellow

        # 方案 A：尝试 gh CLI
        $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
        if ($ghCmd) {
            $ghOut = gh run list --repo "$owner/$repo" --workflow "$workflowName" --status success --limit 1 --json databaseId --jq '.[0].databaseId' 2>&1
            if ($ghOut -and $ghOut -ne "null" -and $ghOut.Trim()) {
                $RunID = $ghOut.Trim()
            }
        }

        # 方案 B：无 gh，用 Python 直接调 GitHub API
        if (-not $RunID) {
            Write-Host "  gh CLI 不可用，使用 Python + GitHub REST API..." -ForegroundColor Yellow

            $pythonScript = @'
import sys, json, urllib.request, os
owner, repo, token = sys.argv[1], sys.argv[2], sys.argv[3]
url = f"https://api.github.com/repos/{owner}/{repo}/actions/workflows"
req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
if token: req.add_header("Authorization", f"Bearer {token}")
with urllib.request.urlopen(req, timeout=15) as r:
    data = json.loads(r.read())
    for wf in data.get("workflows", []):
        if "iOS Build (Unsigned IPA)" in wf.get("name", ""):
            wid = wf["id"]
            print(f"WORKFLOW_ID={wid}")
            break
'@
            $pyFile = Join-Path $TempDir "find_workflow.py"
            $pythonScript | Out-File -FilePath $pyFile -Encoding utf8

            $pythonExe = Get-Command python -ErrorAction SilentlyContinue
            if (-not $pythonExe) {
                $pythonExe = Get-Command python3 -ErrorAction SilentlyContinue
            }
            if (-not $pythonExe) {
                Write-Err "未检测到 Python。请安装 Python 3.8+。"
                exit 1
            }

            $pyOut = & $pythonExe.Source $pyFile $owner $repo $GitHubToken 2>&1
            if ($pyOut -match 'WORKFLOW_ID=(\d+)') {
                $workflowId = $matches[1]
                Write-Host "  Workflow ID: $workflowId" -ForegroundColor Green

                # 拉取该 workflow 的 run 列表
                $runUrl = "https://api.github.com/repos/$owner/$repo/actions/workflows/$workflowId/runs?status=success&per_page=1"
                $runReq = urllib.request.Request($runUrl, headers={"Accept": "application/vnd.github+json"})
                if ($GitHubToken) { $runReq.AddHeader("Authorization", "Bearer $GitHubToken") }
                $pyRunScript = @'
import sys, json, urllib.request
owner, repo, wid, token = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
url = f"https://api.github.com/repos/{owner}/{repo}/actions/workflows/{wid}/runs?status=success&per_page=1"
req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
if token: req.add_header("Authorization", f"Bearer {token}")
with urllib.request.urlopen(req, timeout=15) as r:
    data = json.loads(r.read())
    runs = data.get("workflow_runs", [])
    if runs:
        print(runs[0]["id"])
    else:
        print("NONE")
'@
                $pyRunFile = Join-Path $TempDir "find_run.py"
                $pyRunScript | Out-File -FilePath $pyRunFile -Encoding utf8
                $runOut = & $pythonExe.Source $pyRunFile $owner $repo $workflowId $GitHubToken 2>&1
                if ($runOut -match '^\d+$') {
                    $RunID = $runOut.Trim()
                } elseif ($runOut -eq "NONE") {
                    Write-Err "未找到成功的 workflow run。请在 GitHub 手动触发一次构建："
                    Write-Host "  https://github.com/$owner/$repo/actions/workflows/ios-build.yml" -ForegroundColor Yellow
                    exit 1
                } else {
                    Write-Err "获取 run 列表失败: $runOut"
                    exit 1
                }
            } else {
                Write-Err "查找 workflow 失败: $pyOut"
                exit 1
            }
        }
    }

    if (-not $RunID) {
        Write-Err "无法获取有效的 GitHub Actions run ID。请检查仓库和工作流配置。"
        exit 1
    }
    Write-Ok "Run ID: $RunID"

    # 下载 artifact
    Write-Host "  下载 artifact（可能需要几分钟）..." -ForegroundColor Yellow

    $downloadScript = @"
import sys, json, urllib.request, zipfile, io, os
owner, repo, run_id, token, out_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
headers = {"Accept": "application/vnd.github+json"}
if token: headers["Authorization"] = f"Bearer {token}"

# 1. 获取 run 的 artifacts 列表
url = f"https://api.github.com/repos/{owner}/{repo}/actions/runs/{run_id}/artifacts"
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req, timeout=30) as r:
    data = json.loads(r.read())
    arts = data.get("artifacts", [])
    target = next((a for a in arts if "unsigned" in a.get("name", "")), None)
    if not target:
        print("ERROR: No matching artifact found. Available:", [a['name'] for a in arts])
        sys.exit(1)
    art_url = target["archive_download_url"]

# 2. 下载 zip
req2 = urllib.request.Request(art_url, headers={**headers, "Accept": "application/zip"})
with urllib.request.urlopen(req2, timeout=120) as r:
    content = r.read()

with open(out_path, "wb") as f:
    f.write(content)
print(f"OK: downloaded {len(content)} bytes -> {out_path}")
"@
    $dlPyFile = Join-Path $TempDir "download_artifact.py"
    $downloadScript | Out-File -FilePath $dlPyFile -Encoding utf8
    $pythonExe = (Get-Command python -ErrorAction SilentlyContinue) ?? (Get-Command python3 -ErrorAction SilentlyContinue)
    $dlOut = & $pythonExe.Source $dlPyFile $owner $repo $RunID $GitHubToken $ipaFile 2>&1
    Write-Host "  $dlOut" -ForegroundColor Green

    if (-not (Test-Path $ipaFile) -or (Get-Item $ipaFile).Length -lt 1000) {
        Write-Err "下载失败或文件过小。请检查 GitHub Actions 构建是否成功。"
        Write-Host "  查看构建日志：https://github.com/$owner/$repo/actions" -ForegroundColor Yellow
        exit 1
    }
    Write-Ok "IPA 已下载: $([math]::Round((Get-Item $ipaFile).Length / 1MB, 2)) MB"
}

# ── 启动 Sideloadly 安装 ───────────────────────────────────
Write-Step "启动 Sideloadly 安装到 iPhone"
Write-Host "  IPA : $ipaFile" -ForegroundColor Gray
Write-Host "  Apple ID: $AppleID" -ForegroundColor Gray
if ($DeviceIP) { Write-Host "  设备 IP: $DeviceIP" -ForegroundColor Gray }

$slArgs = @("--ipa", $ipaFile, "--apple-id", $AppleID, "--app-password", $AppPassword)
if ($DeviceIP) { $slArgs += @("--ip", $DeviceIP) }

$proc = Start-Process -FilePath $slExe -ArgumentList $slArgs -PassThru -WindowStyle Hidden
Write-Host "  Sideloadly 已启动 (PID: $($proc.Id))" -ForegroundColor Green
Write-Host "  请稍候，安装通常需要 30~90 秒..." -ForegroundColor Yellow
Write-Host "  （如弹出 Sideloadly 窗口，请留意进度）" -ForegroundColor Gray

# 等待进程退出
Wait-Process -Id $proc.Id -ErrorAction SilentlyContinue
Start-Sleep -Seconds 4

# ── 完成提示 ───────────────────────────────────────────────
Write-Host @"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✅ 安装完成！请在 iPhone 上查找「抖数君后台」图标
  📁 IPA 文件保留在: $ipaFile
  💾 下次续期只需运行（无需重新下载）:
     .\sideload.ps1 -SkipDownload -IPAPath "$ipaFile" `
         -AppleID "$AppleID" -AppPassword "<新AppPassword>"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"@ -ForegroundColor Green

Write-Host @"

⏰ 有效期说明：免费 Apple ID 签名每 7 天过期一次
   过期后重新运行此脚本即可续期（自动重新签名，无需重装）

📡 局域网连接（无需 USB）：
   1. iPhone 和 PC 连同一 WiFi
   2. 在 iPhone「设置」→ Safari → 开启「允许来自未知开发者的网页内容」
   3. 记录 iPhone IP（设置 → Wi-Fi → 点击 ⓘ → IP 地址）
   4. 运行脚本时加上 -DeviceIP "192.168.x.x"
"@ -ForegroundColor Cyan
