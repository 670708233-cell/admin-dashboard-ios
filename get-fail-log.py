#!/usr/bin/env python3
"""下载 workflow run 的原始日志"""
import urllib.request, os, sys

os.environ['HTTP_PROXY'] = 'http://127.0.0.1:10808'
os.environ['HTTPS_PROXY'] = 'http://127.0.0.1:10808'

REPO    = '670708233-cell/admin-dashboard-ios'
RUN_ID  = 38768237454
OUT     = os.path.join(os.environ.get('TEMP', '/tmp'), 'build-log.txt')

# 获取 job ID
jobs_url = f'https://api.github.com/repos/{REPO}/actions/runs/{RUN_ID}/jobs'
r = urllib.request.Request(jobs_url, headers={'Accept': 'application/vnd.github+json'})
with urllib.request.urlopen(r, timeout=30) as resp:
    import json
    jobs = json.loads(resp.read()).get('jobs', [])
    for job in jobs:
        print(f"Job: {job['name']} id={job['id']} conclusion={job['conclusion']}")
        # 获取 step logs
        for step in job.get('steps', []):
            print(f"  Step: {step['name']} {step['conclusion']}")

# 直接下载 run logs
print("\n--- 下载完整日志 ---")
log_url = f'https://github.com/{REPO}/actions/runs/{RUN_ID}/logs'
# GitHub 的 check run logs API
run_data = json.loads(urllib.request.urlopen(
    f'https://api.github.com/repos/{REPO}/actions/runs/{RUN_ID}',
    timeout=15
).read())
print(json.dumps(run_data, indent=2, ensure_ascii=False)[:3000])
