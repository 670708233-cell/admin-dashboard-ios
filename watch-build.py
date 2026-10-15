#!/usr/bin/env python3
"""轮询检查最新 workflow run 状态，完成时下载 artifact"""
import urllib.request
import json
import os
import time
import zipfile
import sys

os.environ['HTTP_PROXY'] = 'http://127.0.0.1:10808'
os.environ['HTTPS_PROXY'] = 'http://127.0.0.1:10808'

REPO = '670708233-cell/admin-dashboard-ios'
WF_ID = 385745789
OUT_DIR = os.path.join(os.environ.get('TEMP', '/tmp'), 'sideload-download')

def req(path, token=''):
    url = 'https://api.github.com' + path
    headers = {'Accept': 'application/vnd.github+json'}
    if token: headers['Authorization'] = f'Bearer {token}'
    r = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(r, timeout=30) as resp:
        return json.loads(resp.read())

def get_latest_run():
    data = req(f'/repos/{REPO}/actions/runs?workflow_id={WF_ID}&per_page=1')
    runs = data.get('workflow_runs', [])
    return runs[0] if runs else None

print("等待构建完成...")
print("访问进度：https://github.com/670708233-cell/admin-dashboard-ios/actions\n")

# 轮询（最多等 15 分钟）
for i in range(90):
    run = get_latest_run()
    if not run:
        print("暂无 run，继续等待...")
        time.sleep(10)
        continue
    
    status = run['status']
    conclusion = run['conclusion']
    run_id = run['id']
    created = run['created_at'][:19]
    
    print(f"[{i*10+10}s] Run #{run_id} | status={status} | conclusion={conclusion} | created={created}")
    
    if status == 'completed':
        if conclusion == 'success':
            print("\n构建成功！下载 artifact...")
            # 获取 artifact URL
            art_data = req(f'/repos/{REPO}/actions/runs/{run_id}/artifacts')
            arts = art_data.get('artifacts', [])
            target = next((a for a in arts if 'unsigned' in a.get('name', '')), None)
            if target:
                art_url = target['archive_download_url']
                os.makedirs(OUT_DIR, exist_ok=True)
                ipa_path = os.path.join(OUT_DIR, 'AdminDashboard-unsigned.ipa')
                
                headers = {'Accept': 'application/zip'}
                r = urllib.request.Request(art_url, headers=headers)
                with urllib.request.urlopen(r, timeout=120) as resp:
                    data = resp.read()
                with open(ipa_path, 'wb') as f:
                    f.write(data)
                print(f"已下载到: {ipa_path}")
                print(f"文件大小: {len(data)/1024/1024:.2f} MB")
            else:
                print("未找到 unsigned IPA artifact")
        elif conclusion == 'failure':
            print(f"\n构建失败！请查看日志：https://github.com/{REPO}/actions/runs/{run_id}")
        break
    elif status == 'in_progress':
        print("  构建进行中，等待...")
        time.sleep(10)
    else:
        break

print("\n完成后请打开 Sideloadly，拖入 IPA，填写 App Password，点 Start")
