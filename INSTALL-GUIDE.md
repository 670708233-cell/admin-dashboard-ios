# iOS 真机安装完整指南（零成本）

## 第一步：推送到 GitHub（只需一次）

```powershell
cd d:\hubulider\dsj\doushujunfull\admin-dashboard-ios

# 1. 在 github.com 创建空仓库 admin-dashboard-ios
# 2. 添加远程并推送
git remote add origin https://github.com/你的用户名/admin-dashboard-ios.git
git push -u origin master
```

## 第二步：准备 Apple ID

1. 打开 [appleid.apple.com](https://appleid.apple.com/account/manage)
2. 登录你的 Apple ID（免费注册即可）
3. 进入「登录与安全」→ 找到「应用专用密码」→ 生成一个新密码
4. 记录格式：`abcd-efgh-ijkl-mnop`（16 位，含连字符）

## 第三步：下载 Sideloadly

→ [https://sideloadly.io](https://sideloadly.io)
→ 下载 Windows 版本并安装（免费版完全够用）

## 第四步：触发构建并安装

### 方式 A：双击批处理文件（最简单）

```
sideload-install.bat "你的邮箱@gmail.com" "abcd-efgh-ijkl-mnop"
```

### 方式 B：PowerShell 命令

```powershell
# 首次：自动触发 CI → 下载 IPA → 安装到手机（全程约 3-5 分钟）
.\sideload.ps1 -AppleID "你的邮箱@gmail.com" -AppPassword "abcd-efgh-ijkl-mnop"

# 续期（IPA 已保留在 %TEMP%，无需重新下载）
.\sideload.ps1 -SkipDownload -AppleID "你的邮箱@gmail.com" -AppPassword "新AppPassword"

# 局域网模式（iPhone 和 PC 同一 WiFi，无需 USB）
.\sideload.ps1 -AppleID "你的邮箱@gmail.com" -AppPassword "abcd-efgh-ijkl-mnop" -DeviceIP "192.168.1.100"
```

### 查看 iPhone IP 地址
> 设置 → Wi-Fi → 点击当前网络右侧 ⓘ → IP 地址

---

## 工作流程说明

```
git push → GitHub Actions 自动触发
              │
              ▼
         macOS 云机编译（约 2-3 分钟）
              │
              ▼
         产出 unsigned IPA（未签名）
              │
              ▼
    sideload.ps1 下载 IPA
              │
              ▼
    Sideloadly + 免费 Apple ID 签名安装
              │
              ▼
         iPhone 出现「抖数君后台」
         有效期：7 天
```

---

## 7 天后过期怎么办？

免费 Apple ID 签名的 App 每 7 天需要重新签名（Apple 官方限制，无法绕过）。

**续期只需 30 秒：**
```powershell
.\sideload-refresh.bat "你的邮箱@gmail.com" "app-password"
```

> 注意：每次续期建议使用**不同的应用专用密码**（在 Apple 网站生成新的），旧密码可能被系统回收。

---

## 常见问题

**Q: GitHub Actions 一直失败？**
→ 检查 [github.com/你的用户名/admin-dashboard-ios/actions](https://github.com/你的用户名/admin-dashboard-ios/actions) 的日志，最常见是 XcodeGen 阶段报错。

**Q: Sideloadly 说"网络错误"？**
→ 确保 iPhone 和 PC 在同一 WiFi；USB 模式可省略 `-DeviceIP`。

**Q: 安装后 App 闪退？**
→ 可能是代码编译有问题，检查 Xcode 编译日志（workflow 日志中有 `Build unsigned IPA` 输出）。

**Q: 想换 Apple ID？**
→ 直接用新 Apple ID 运行脚本即可，旧证书会被覆盖。
