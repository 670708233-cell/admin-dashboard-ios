# 手动配置 GitHub PAT 推送

## 第一步：获取 GitHub Token

1. 打开 https://github.com/settings/tokens/new
2. Note: 填 `admin-dashboard-ios-push`
3. Expiration: 选 `No expiration`
4. 勾选权限：**repo**（全勾选）
5. 点绿色按钮 **Generate token**
6. 复制生成的 token（格式 `ghp_xxxxxxxxxxxx`）

## 第二步：在 PowerShell 运行（替换 YOUR_TOKEN）

```powershell
git -C d:/hubulider/dsj/doushujunfull/admin-dashboard-ios remote set-url origin https://YOUR_TOKEN@github.com/670708233-cell/admin-dashboard-ios.git
git -C d:/hubulider/dsj/doushujunfull/admin-dashboard-ios push origin master
```

---

## Sideloadly App Password 说明

Sideloadly v0.70.1 的 App Password 输入框在点击 "Advanced Options" 展开后才可见。
或者直接在 Apple ID 输入框下方找一个小密码输入框（没有标签文字，紧贴着 Apple ID）。

如果还是没有：
- 退出 Sideloadly 重启，可能 UI 版本有差异
- 或者用网页版：先点 Apple ID 下拉框 → 选择账号 → 会弹出输入密码的对话框