#!/usr/bin/env python3
"""监控 GitHub Actions 构建，完成后自动下载 IPA"""
import urllib.request, json, os, time, sys

os.environ['HTTP_PROXY'] = 'http://127.0.0.1:10808'
os.environ['HTTPS_PROXY'] = 'http://127.0.0.1:10808'

REPO    = '670708233-cell/admin-dashboard-ios'
OUT_DIR = os.path.join(os.environ.get('TEMP', '/tmp'), 'sideload-ios-ipa')
BASE    = 'https://api.github.com'

def req(path):
    r = urllib.request.Request(BASE + path,
        headers={'Accept': 'application/vnd.github+json'})
    with urllib.request.urlopen(r, timeout=30) as resp:
        return json.loads(resp.read())

print("等待 GitHub Actions 构建完成...")
print("在线查看: https://github.com/670708233-cell/admin-dashboard-ios/actions\n")

for i in range(120):
    time.sleep(10)
    # 获取最新 run
    data   = req(f'/repos/{REPO}/actions/runs?per_page=1')
    runs   = data.get('workflow_runs', [])
    if not runs:
        continue
    run    = runs[0]
    rid    = run['id']
    status = run['status']
    concl  = run.get('conclusion', '')

    icon = '?'
    if status == 'completed':
        icon = 'OK' if concl == 'success' else ('FAIL' if concl == 'failure' else concl)
    elif status == 'in_progress':
        icon = '>>'

    print(f"\r[{icon:4s}] Run #{rid} | {status:12s} | {concl or '—'}", end='', flush=True)

    if status == 'completed':
        print()
        if concl == 'success':
            print("\n[OK] 构建成功！下载 IPA...")
            arts = req(f'/repos/{REPO}/actions/runs/{rid}/artifacts').get('artifacts', [])
            target = next((a for a in arts if 'unsigned' in a.get('name','')), None)
            if target:
                os.makedirs(OUT_DIR, exist_ok=True)
                ipa_path = os.path.join(OUT_DIR, 'AdminDashboard-unsigned.ipa')
                r2 = urllib.request.Request(target['archive_download_url'],
                    headers={'Accept': 'application/zip'})
                with urllib.request.urlopen(r2, timeout=180) as resp:
                    data = resp.read()
                with open(ipa_path, 'wb') as f:
                    f.write(data)
                print(f"[OK] IPA: {ipa_path} ({len(data)/1024/1024:.1f} MB)")
                print("\n" + "="*50)
                print("下一步：打开 Sideloadly")
                print("1. Apple ID: 670708233@qq.com")
                print("2. 拖入上列 IPA 文件")
                print("3. 点 [Start] 按钮 → 弹出框填密码:")
                print("   gzvu-olkd-khxc-bxcx")
                print("4. 等待安装完成")
                print("="*50)
            else:
                print("[WARN] 未找到 IPA artifact")
                print(f"手动下载: https://github.com/{REPO}/actions/runs/{rid}")
        else:
            print(f"\n[FAIL] 查看日志: https://github.com/{REPO}/actions/runs/{rid}")
        break
