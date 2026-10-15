#!/usr/bin/env python3
"""获取 workflow run 的失败步骤日志"""
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
    with urllib.request.urlopen(r, timeout=30) as resp:
        return json.loads(resp.read())

try:
    # 获取 job 列表
    data = req(f'/repos/{REPO}/actions/runs/{RUN_ID}/jobs')
    jobs = data.get('jobs', [])
    for job in jobs:
        print(f"Job: {job['name']} | status={job['status']} | conclusion={job['conclusion']}")
        
        # 获取每个 job 的 steps
        steps_url = f"/repos/{REPO}/actions/jobs/{job['id']}/steps"
        steps_data = req(steps_url)
        steps = steps_data.get('steps', [])
        for step in steps:
            icon = "?"
            if step['conclusion'] == 'success': icon = "OK"
            elif step['conclusion'] == 'failure': icon = "FAIL"
            elif step['conclusion'] == 'cancelled': icon = "CANC"
            print(f"  [{icon}] {step['name']}")
            if step['conclusion'] == 'failure':
                # 获取失败 step 的日志
                try:
                    log_url = f"/repos/{REPO}/actions/logs/{step['number']}"
                    log_data = req(log_url)
                    logs = log_data.get('steps', [])
                    for lg in logs[-5:]:  # 最后5条日志
                        print(f"      {lg.get('start_time','')[:19]} | {lg.get('summary','').strip()[:200]}")
                except:
                    pass
except Exception as e:
    print(f"ERROR: {e}")
