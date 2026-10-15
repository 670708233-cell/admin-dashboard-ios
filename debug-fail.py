#!/usr/bin/env python3
"""获取失败详情 - 通过 workflow run 的 check run API"""
import urllib.request
import json
import os

os.environ['HTTP_PROXY'] = 'http://127.0.0.1:10808'
os.environ['HTTPS_PROXY'] = 'http://127.0.0.1:10808'

REPO = '670708233-cell/admin-dashboard-ios'
RUN_ID = 38767771920
base = 'https://api.github.com'

def req(path):
    url = base + path
    headers = {'Accept': 'application/vnd.github+json'}
    r = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(r, timeout=30) as resp:
        return resp.read()

try:
    # 获取 jobs
    data = json.loads(req(f'/repos/{REPO}/actions/runs/{RUN_ID}/jobs'))
    jobs = data.get('jobs', [])
    print(f"Jobs: {len(jobs)}")
    
    for job in jobs:
        print(f"\nJob: {job['name']} (id={job['id']}) conclusion={job['conclusion']}")
        
        # 获取步骤日志 - 用 check_runs 接口
        steps_data = json.loads(req(f'/repos/{REPO}/actions/jobs/{job["id"]}/steps'))
        steps = steps_data.get('steps', [])
        
        for s in steps:
            status_icon = '?'
            if s['conclusion'] == 'success': status_icon = 'OK'
            elif s['conclusion'] == 'failure': status_icon = 'FAIL'
            elif s['conclusion'] == 'cancelled': status_icon = 'CANC'
            print(f"  [{status_icon}] {s['name']}")
except Exception as e:
    print(f"ERROR: {e}")
