#!/usr/bin/env python3
"""
监控 GitHub Actions 构建，完成后自动下载 IPA 并提示使用 Sideloadly 安装。
用法: python monitor-build.py
"""
import urllib.request
import json
import os
import time
import sys

PROXY = 'http://127.0.0.1:10808'
os.environ['HTTP_PROXY'] = PROXY
os.environ['HTTPS_PROXY'] = PROXY

REPO    = '670708233-cell/admin-dashboard-ios'
WF_NAME = 'iOS Build (Unsigned IPA)'
OUT_DIR = os.path.join(os.environ.get('TEMP', '/tmp'), 'sideload-ios-ipa')

BASE = 'https://api.github.com'

def req(path):
    url = BASE + path
    headers = {'Accept': 'application/vnd.github+json'}
    r = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(r, timeout=30) as resp:
        return json.loads(resp.read())

def status_msg(conclusion):
    colors = {
        'success': '[OK]',
        'failure': '[FAIL]',
        'in_progress': '[..]',
        'queued':    '[..]',
    }
    return colors.get(conclusion, '[??]')

print("=" * 55)
print("  iOS Build Monitor")
print(f"  Repo:   {REPO}")
print(f"  Wait:   build completion + auto-download")
print(f"  IPA:    {OUT_DIR}")
print("=" * 55)
print()

# 轮询（最多 20 分钟）
for i in range(120):
    # 获取最新 run
    data = req(f'/repos/{REPO}/actions/runs?workflow_id='
               f'{req("/repos/"+REPO+"/actions/workflows")}'
               f'{""][0]["id"]}&per_page=1')
    runs = data.get('workflow_runs', [])
    if not runs:
        print(f"[{i*10+10}s] 暂无运行记录，继续等待...")
        time.sleep(10)
        continue

    run = runs[0]
    rid    = run['id']
    concl  = run.get('conclusion', run['status'])
    created = run['created_at'][:19]

    # 只打印状态变化
    print(f"\r[{i*10+10:3d}s] {status_msg(concl)} Run #{rid} | {concl} | {created}", end='', flush=True)

    if run['status'] == 'completed':
        print()
        if concl == 'success':
            print("\n[OK] 构建成功！正在下载 IPA...")
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
                mb = len(data) / 1024 / 1024
                print(f"[OK] IPA 已保存: {ipa_path}")
                print(f"     文件大小: {mb:.2f} MB")
                print()
                print("-" * 55)
                print("  下一步：打开 Sideloadly")
                print("  1. Apple ID: 670708233@qq.com")
                print("  2. 拖入 IPA 文件")
                print("  3. 点 Start 按钮 → 弹出框填 App Password")
                print("     Password: gzvu-olkd-khxc-bxcx")
                print("  4. 等待安装完成")
                print("-" * 55)
            else:
                print("[WARN] 未找到 unsigned IPA artifact")
                print(f"       请手动下载: https://github.com/{REPO}/actions/runs/{rid}")
        elif concl == 'failure':
            print(f"\n[FAIL] 构建失败！")
            print(f"       查看日志: https://github.com/{REPO}/actions/runs/{rid}")
        break
    elif run['status'] == 'in_progress':
        time.sleep(10)
    else:
        break

print()
