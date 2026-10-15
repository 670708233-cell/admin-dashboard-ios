#!/usr/bin/env python3
"""GitHub Actions 触发器 - 通过代理调用 API"""
import urllib.request
import json
import os
import sys

# 代理设置
os.environ['HTTP_PROXY'] = 'http://127.0.0.1:10808'
os.environ['HTTPS_PROXY'] = 'http://127.0.0.1:10808'

GITHUB_TOKEN = os.environ.get('GH_TOKEN', '')
REPO = '670708233-cell/admin-dashboard-ios'
WORKFLOW_NAME = 'iOS Build (Unsigned IPA)'

base = 'https://api.github.com'

def req(method, path, body=None):
    url = base + path
    headers = {'Accept': 'application/vnd.github+json'}
    if GITHUB_TOKEN:
        headers['Authorization'] = f'Bearer {GITHUB_TOKEN}'
    data = json.dumps(body).encode() if body else None
    r = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(r, timeout=30) as resp:
        return json.loads(resp.read())

try:
    # 1. 获取所有 workflows
    data = req('GET', f'/repos/{REPO}/actions/workflows')
    wfs = data.get('workflows', [])
    print(f"Found {len(wfs)} workflows:")
    for wf in wfs:
        print(f"  ID={wf['id']} name='{wf['name']}' path={wf['path']}")

    # 2. 找目标 workflow
    target = next((w for w in wfs if WORKFLOW_NAME in w.get('name', '')), None)
    if not target:
        print(f"\nERROR: Workflow '{WORKFLOW_NAME}' not found!")
        sys.exit(1)

    wf_id = target['id']
    print(f"\nTriggering workflow ID={wf_id}...")

    # 3. 手动触发（dispatch）
    result = req('POST', f'/repos/{REPO}/actions/workflows/{wf_id}/dispatches',
                 body={'ref': 'master'})
    print(f"Triggered! Status: {result.get('state', 'ok')}")
    print("\n请访问以下链接查看构建进度：")
    print(f"https://github.com/{REPO}/actions")

except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
