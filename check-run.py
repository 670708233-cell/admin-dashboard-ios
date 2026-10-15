#!/usr/bin/env python3
"""检查最近一次 workflow run 的状态"""
import urllib.request
import json
import os

os.environ['HTTP_PROXY'] = 'http://127.0.0.1:10808'
os.environ['HTTPS_PROXY'] = 'http://127.0.0.1:10808'

REPO = '670708233-cell/admin-dashboard-ios'
WF_ID = 385745789

base = 'https://api.github.com'

def req(path):
    url = base + path
    headers = {'Accept': 'application/vnd.github+json'}
    r = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(r, timeout=15) as resp:
        return json.loads(resp.read())

try:
    # 查最近一次 run
    data = req(f'/repos/{REPO}/actions/runs?workflow_id={WF_ID}&per_page=3')
    runs = data.get('workflow_runs', [])
    if not runs:
        print("No runs found!")
    else:
        for run in runs:
            print(f"Run #{run['id']} | status={run['status']} | conclusion={run['conclusion']} | created={run['created_at'][:19]}")
        print("\n最近一次构建状态：")
        r = runs[0]
        url = f"https://github.com/{REPO}/actions/runs/{r['id']}"
        if r['conclusion'] == 'success':
            print(f"✅ 构建成功！打开查看并下载 IPA：{url}")
        elif r['status'] == 'in_progress':
            print(f"🔄 构建进行中，请等待... {url}")
        else:
            print(f"❌ 构建失败，查看日志：{url}")
except Exception as e:
    print(f"ERROR: {e}")
