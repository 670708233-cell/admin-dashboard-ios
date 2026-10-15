<#
.SYNOPSIS
    抖数君 iOS - Sideloadly 一键安装脚本
.PARAMETER AppleID
    免费 Apple ID 邮箱
.PARAMETER AppPassword
    Apple ID 应用专用密码（16位）
.PARAMETER DeviceIP
    iPhone 局域网 IP（可选，USB 直连时省略）
.PARAMETER SkipDownload
    跳过 CI 下载，使用本地 IPA
.PARAMETER IPAPath
    本地 IPA 路径
.EXAMPLE
    .\sideload.ps1 -AppleID "email@gmail.com" -AppPassword "abcd-efgh-ijkl-mnop"
#>
param(
    [Parameter(Mandatory=$true)][string]$AppleID,
    [Parameter(Mandatory=$true)][string]$AppPassword,
    [string]$DeviceIP = "",
    [switch]$SkipDownload,
    [string]$IPAPath = ""
)

$ErrorActionPreference = "Stop"
$TempDir = "$env:TEMP\dl-ipa"

function Out-Step { param($m) Write-Host "`n>>> $m" -ForegroundColor Cyan }
function Out-Ok  { param($m) Write-Host "  OK  $m" -ForegroundColor Green }
function Out-Err { param($m) Write-Host "ERR  $m" -ForegroundColor Red; exit 1 }

# ── 检查 Sideloadly ────────────────────────────────────────
Out-Step "检查 Sideloadly"
$slPaths = @(
    "${env:ProgramFiles}\Sideloadly\sideloading.exe",
    "${env:ProgramFiles(x86)}\Sideloadly\sideloading.exe",
    "$env:LOCALAPPDATA\Sideloadly\sideloading.exe"
)
$sl = $null
foreach ($p in $slPaths) { if (Test-Path $p) { $sl = $p; break } }
if (-not $sl) { Out-Err "未找到 Sideloadly，请先从 https://sideloadly.io 下载安装" }
Out-Ok "Sideloadly: $sl"

# ── 获取 IPA ───────────────────────────────────────────────
$ipaFile = ""

if ($SkipDownload) {
    if (-not $IPAPath -or -not (Test-Path $IPAPath)) {
        Out-Err "请用 -IPAPath 指定本地 IPA 文件"
    }
    $ipaFile = $IPAPath
    Out-Step "使用本地 IPA: $ipaFile"
} else {
    Out-Step "下载 IPA（GitHub Actions）"
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
    $ipaFile = Join-Path $TempDir "AdminDashboard-unsigned.ipa"

    # 用 Python 下载 GitHub Actions artifact
    $pyScript = @'
import urllib.request, json, os, sys
os.environ["HTTP_PROXY"] = "http://127.0.0.1:10808"
os.environ["HTTPS_PROXY"] = "http://127.0.0.1:10808"
owner, repo, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
url = f"https://api.github.com/repos/{owner}/{repo}/actions/runs?per_page=5"
r = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
with urllib.request.urlopen(r, timeout=20) as resp:
    data = json.loads(resp.read())
    runs = data.get("workflow_runs", [])
    # 找最新的成功的 run
    for run in runs:
        if run.get("conclusion") == "success" and "ios" in str(run.get("display_title","")):
            run_id = run["id"]
            art_url = f"https://api.github.com/repos/{owner}/{repo}/actions/runs/{run_id}/artifacts"
            ar = urllib.request.Request(art_url, headers={"Accept": "application/vnd.github+json"})
            with urllib.request.urlopen(ar, timeout=20) as resp2:
                arts = json.loads(resp2.read()).get("artifacts", [])
                target = next((a for a in arts if "unsigned" in a.get("name","")), None)
                if target:
                    print(f"FOUND:{run_id}")
                    break
            else:
                continue
            break
    else:
        print("NOT_FOUND")
        sys.exit(1)
'@
    $pyFile = Join-Path $TempDir "find_run.py"
    $pyScript | Out-File -FilePath $pyFile -Encoding utf8

    $pyExe = Get-Command python -ErrorAction SilentlyContinue
    if (-not $pyExe) { $pyExe = Get-Command python3 -ErrorAction SilentlyContinue }
    if (-not $pyExe) { Out-Err "需要 Python 3.8+，请安装后重试" }

    $pyOut = & $pyExe.Source $pyFile "670708233-cell" "admin-dashboard-ios" $ipaFile 2>&1
    Write-Host "  $pyOut" -ForegroundColor Gray

    # 实际下载
    $dlScript = @'
import urllib.request, json, os, sys
os.environ["HTTP_PROXY"] = "http://127.0.0.1:10808"
os.environ["HTTPS_PROXY"] = "http://127.0.0.1:10808"
owner, repo, run_id, out_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
art_url = f"https://api.github.com/repos/{owner}/{repo}/actions/runs/{run_id}/artifacts"
r = urllib.request.Request(art_url, headers={"Accept": "application/vnd.github+json"})
with urllib.request.urlopen(r, timeout=20) as resp:
    arts = json.loads(resp.read()).get("artifacts", [])
    target = next((a for a in arts if "unsigned" in a.get("name","")), None)
    if not target:
        print("NO_ARTIFACT")
        sys.exit(1)
    dl_url = target["archive_download_url"]
    r2 = urllib.request.Request(dl_url, headers={"Accept": "application/zip"})
    with urllib.request.urlopen(r2, timeout=180) as resp2:
        data = resp2.read()
with open(out_path, "wb") as f:
    f.write(data)
print(f"OK:{len(data)//1024//1024}MB")
'@
    $dlFile = Join-Path $TempDir "download.py"
    $dlScript | Out-File -FilePath $dlFile -Encoding utf8

    if (Test-Path $ipaFile) { Remove-Item $ipaFile -Force }

    # 先找 run ID
    $findOut = & $pyExe.Source $pyFile "670708233-cell" "admin-dashboard-ios" $ipaFile 2>&1
    Write-Host "  $findOut" -ForegroundColor Gray

    # 用 gh CLI 或手动指定 run
    $runId = ""
    $ghCmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($ghCmd) {
        $runId = & gh run list --repo "670708233-cell/admin-dashboard-ios" --workflow "iOS Build" --status success --limit 1 --json databaseId --jq '.[0].databaseId' 2>$null
        $runId = $runId -replace '"',''
    }

    if (-not $runId -or $runId -eq "null") {
        Out-Err "无法获取 GitHub Actions run ID。请检查仓库是否已推送，或在 https://github.com/670708233-cell/admin-dashboard-ios/actions 手动触发构建后运行此脚本。"
    }

    Write-Host "  Run ID: $runId" -ForegroundColor Yellow
    & $pyExe.Source $dlFile "670708233-cell" "admin-dashboard-ios" $runId $ipaFile
    $dlResult = $LASTEXITCODE
    Write-Host "  Download exit: $dlResult"

    if (-not (Test-Path $ipaFile) -or (Get-Item $ipaFile).Length -lt 1000) {
        Out-Err "IPA 下载失败。请确认 GitHub Actions 构建成功。"
    }
    Out-Ok "IPA 已下载: $([math]::Round((Get-Item $ipaFile).Length/1MB,2)) MB"
}

# ── 启动 Sideloadly ────────────────────────────────────────
Out-Step "启动 Sideloadly"
Write-Host "  IPA    : $ipaFile" -ForegroundColor Gray
Write-Host "  AppleID: $AppleID" -ForegroundColor Gray
if ($DeviceIP) { Write-Host "  DeviceIP: $DeviceIP" -ForegroundColor Gray }

$slArgs = @("--ipa", $ipaFile, "--apple-id", $AppleID, "--app-password", $AppPassword)
if ($DeviceIP) { $slArgs += @("--ip", $DeviceIP) }

Write-Host "  正在启动 Sideloadly..." -ForegroundColor Yellow
Start-Process -FilePath $sl -ArgumentList $slArgs -PassThru | Out-Null
Write-Host "  Sideloadly 已启动，请在弹出的窗口中确认安装。" -ForegroundColor Green
Write-Host "  （App Password: $AppPassword）" -ForegroundColor Gray
Write-Host "  等待完成后 iPhone 上会出现「抖数君后台」图标。" -ForegroundColor Green
