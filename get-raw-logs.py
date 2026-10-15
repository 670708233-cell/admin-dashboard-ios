#!/usr/bin/env python3
"""下载 workflow run 的 step 原始日志到本地文件"""
import urllib.request, json, os, sys, zipfile, io

os.environ['HTTP_PROXY'] = 'http://127.0.0.1:10808'
os.environ['HTTPS_PROXY'] = 'http://127.0.0.1:10808'

REPO   = '670708233-cell/admin-dashboard-ios'
RUN_ID = 38768439858
OUT    = os.path.join(os.environ.get('TEMP', '/tmp'), 'gh-build-log.txt')

BASE = 'https://api.github.com'

def req(path):
    r = urllib.request.Request(BASE + path, headers={'Accept': 'application/vnd.github+json'})
    with urllib.request.urlopen(r, timeout=30) as resp:
        return resp.read()

# 获取 jobs
jobs_data = json.loads(req(f'/repos/{REPO}/actions/runs/{RUN_ID}/jobs'))
print(f"Jobs: {len(jobs_data.get('jobs', []))}")

for job in jobs_data.get('jobs', []):
    print(f"\n=== Job: {job['name']} (id={job['id']}) ===")
    print(f"Conclusion: {job['conclusion']}")
    
    # 获取 step logs (需要 job log token)
    # GitHub API v3 提供的 step logs 端点
    step_logs_url = f"https://pipelines.actions.githubusercontent.com/{job['id']}/_steps"
    # 用 runs/logs 替代
    pass

# 直接下载所有 log 文件
print("\n=== 尝试下载完整 log zip ===")
log_req = urllib.request.Request(
    f'https://api.github.com/repos/{REPO}/actions/runs/{RUN_ID}/logs',
    headers={'Accept': 'application/zip'}
)
try:
    with urllib.request.urlopen(log_req, timeout=30) as resp:
        zdata = resp.read()
        print(f"Log zip size: {len(zdata)} bytes")
        with open(os.path.join(os.environ['TEMP'], 'run-logs.zip'), 'wb') as f:
            f.write(zdata)
        # 解压查看
        with zipfile.ZipFile(io.BytesIO(zdata)) as z:
            for name in z.namelist():
                content = z.read(name).decode('utf-8', errors='replace')
                with open(OUT, 'a', encoding='utf-8') as out:
                    out.write(f"\n=== {name} ===\n")
                    out.write(content[-4000:])  # 最后4000字符（错误通常在末尾）
        print(f"Log saved to: {OUT}")
except Exception as e:
    print(f"Failed to download logs: {e}")
    print("Trying alternative method...")
    
    # 备选：通过 check_runs 获取每个 step 的 log URL
    runs_data = json.loads(req(f'/repos/{REPO}/actions/runs/{RUN_ID}'))
    check_runs_url = runs_data.get('check_runs_url', '')
    if check_runs_url:
        print(f"Check runs URL: {check_runs_url}")
        cr_data = json.loads(req(check_runs_url))
        for cr in cr_data.get('check_runs', [])[:3]:
            print(f"  CheckRun: {cr['name']} conclusion={cr['conclusion']}")
            logs_url = cr.get('logs_url', '')
            if logs_url:
                print(f"    Logs URL: {logs_url}")
