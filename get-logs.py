#!/usr/bin/env python3
"""获取 workflow run 的完整日志"""
import urllib.request
import json
import os

os.environ['HTTP_PROXY'] = 'http://127.0.0.1:10808'
os.environ['HTTPS_PROXY'] = 'http://127.0.0.1:10808'

REPO = '670708233-cell/admin-dashboard-ios'
RUN_ID = 38766709606

base = 'https://api.github.com'

def req(path):
    url = base + path
    headers = {'Accept': 'application/vnd.github+json'}
    r = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(r, timeout=60) as resp:
        return json.loads(resp.read())

# 获取 jobs
data = req(f'/repos/{REPO}/actions/runs/{RUN_ID}/jobs')
jobs = data.get('jobs', [])
print(f"Jobs found: {len(jobs)}")
for job in jobs:
    print(f"\n=== Job: {job['name']} (id={job['id']}) ===")
    print(f"结论: {job['conclusion']}")
    
    # 获取 conclusion 为 failure 的 step logs
    # 用 /runs/{run_id}/logs 直接获取所有日志
    pass

# 直接下载 run 的所有 step 日志
print(f"\n--- 下载 run {RUN_ID} 的完整日志 ---")
log_data = req(f'/repos/{REPO}/actions/runs/{RUN_ID}/logs')
for item in log_data:
    name = item.get('name', 'unknown')
    url = item.get('url', '')
    print(f"Step: {name} | Log: {url}")
