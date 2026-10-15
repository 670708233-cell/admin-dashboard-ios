#!/usr/bin/env python3
"""直接下载 workflow run 的原始日志"""
import urllib.request
import os

os.environ['HTTP_PROXY'] = 'http://127.0.0.1:10808'
os.environ['HTTPS_PROXY'] = 'http://127.0.0.1:10808'

RUN_ID = 38767771920
REPO = '670708233-cell/admin-dashboard-ios'

url = f'https://api.github.com/repos/{REPO}/actions/runs/{RUN_ID}/jobs'
req = urllib.request.Request(url, headers={'Accept': 'application/vnd.github+json'})

with urllib.request.urlopen(req, timeout=30) as resp:
    import json
    data = json.loads(resp.read())
    
for job in data.get('jobs', []):
    print(f"Job: {job['name']} | id={job['id']}")
    steps_url = f"https://api.github.com/repos/{REPO}/actions/jobs/{job['id']}/steps"
    req2 = urllib.request.Request(steps_url, headers={'Accept': 'application/vnd.github+json'})
    with urllib.request.urlopen(req2, timeout=15) as resp2:
        steps = json.loads(resp2.read()).get('steps', [])
        for s in steps:
            print(f"  {s['name']}: {s['conclusion']}")
