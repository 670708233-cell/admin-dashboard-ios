# 抖数君后台 · iOS 端

与 `admin-dashboard-android` 功能对等的 SwiftUI 原生 App：同一套后端接口（`http://113.44.37.234:8000/api/`）、同一套科技风暗色 UI（深空背景 + 网格 + 流动光晕 + 玻璃拟态卡片 + 霓虹辉光）。

## 功能清单（与 Android 端一致）

| 模块 | 功能 |
|---|---|
| 登录 | JWT 登录，token 存 Keychain，自动恢复登录态 |
| 仪表盘 | 网页端/小程序/支付宝数据概览、API 分类统计、Cookie 池统计、近 7 天增长趋势图（Swift Charts） |
| 仪表盘 | **定时自动刷新**（关闭/15秒/30秒/1分钟/5分钟，间隔持久化，显示上次更新时间）+ 手动刷新 |
| 网页端用户 | 搜索 + 用户类型/今日查询筛选 + 分页（上一页/下一页/跳页）；操作：设超级VIP、关闭VIP、改VIP时长、改余额、改密码、删除 |
| 微信小程序用户 | 搜索 + 类型筛选 + 分页；操作：开通/续费 VIP（**套餐下拉**，8 个套餐含价格/时长/每日上限）、关闭 VIP、查看套餐详情 |
| 支付宝小程序用户 | 同上（无套餐详情接口，故不含详情） |
| Cookie 池 | 统计卡片、搜索、有效/失效本地筛选、分页、添加/批量添加、切换激活态、删除/批量删除 |
| 操作日志 | 搜索 + 分页 + 详情弹窗 |
| AI Key 管理 | 统计、熔断冷却时长配置、测试/启禁/重置熔断/编辑/删除/新增 |
| 系统设置 | 通用设置（键值动态表单）、站点状态、微信/支付宝小程序键值设置增删改 |
| 全局 | 抽屉导航、修改密码、退出登录、Toast 提示 |

## 构建运行（需要 macOS + Xcode 15+）

> 代码在 Windows 环境下编写，未经真机编译验证；首次在 Xcode 打开如有零星语法/API 适配，按报错修即可（均为 SwiftUI 常见小问题）。

### 方式一：XcodeGen（推荐）

```bash
cd admin-dashboard-ios
xcodegen generate        # 生成 AdminDashboard.xcodeproj
open AdminDashboard.xcodeproj
```

Xcode 中选择 `AdminDashboard` target，签名 team 选你的开发账号，iOS Deployment Target 已是 **16.0**，直接 ⌘R 运行。

### 方式二：手动建工程

1. Xcode → Create New Project → iOS → App，名字 `AdminDashboard`，Interface 选 **SwiftUI**，Minimum Deployments 选 **iOS 16.0**。
2. 删掉自动生成的 `ContentView.swift`，把本仓库 `AdminDashboard/` 目录下所有 `.swift` 文件拖进工程（勾选 Copy items if needed + target）。
3. Info 页签添加 `App Transport Security Settings` → `Allow Arbitrary Loads = YES`（后端是 HTTP，不开这个连不上；`Info.plist` 已含此项，手动建工程时照抄即可）。

## 目录结构

```
admin-dashboard-ios/
├── project.yml                  # XcodeGen 配置
└── AdminDashboard/
    ├── AdminDashboardApp.swift  # 入口（登录态分流）
    ├── Info.plist               # 含 ATS 例外
    ├── Core/
    │   ├── Models.swift         # 全部 API 模型（显式 CodingKeys）
    │   ├── APIClient.swift      # URLSession + async/await 客户端
    │   ├── AuthStore.swift      # 登录态 + Keychain
    │   ├── RefreshIntervalStore.swift
    │   ├── Theme.swift          # 科技风配色
    │   └── Components.swift     # 玻璃卡片/网格背景/分页器/筛选下拉等
    └── Views/
        ├── LoginView.swift      MainView.swift（抽屉导航）
        ├── DashboardView.swift  WebUsersView.swift  MiniUsersView.swift
        ├── AlipayUsersView.swift  CookieView.swift  AiKeysView.swift
        └── LogsView.swift       SettingsView.swift
```

## 实现要点（与后端契约对齐，踩过的坑都规避了）

1. **混合命名**：后端 Dashboard 返回驼峰键（`todayRegistrations`），列表返回 snake_case（`created_at`、`vip_info`）。Swift 侧所有模型都写了显式 `CodingKeys`，不依赖 `convertFromSnakeCase`。
2. **列表键名**：分页数据在 `data.users` / `data.cookies` 下（不是 `list/items`），`PageData.rows` 已做四种兼容。
3. **查询参数**：后端只认 `page / page_size / search / vip_type / has_query_today`（Android 早期传 `pageSize/keyword` 被忽略的坑已规避）。
4. **小程序 set-vip**：按 `user_id` 列查找（不是行 id），请求体为 `user_id/is_vip/package_id/start_date/end_date`；`start_date` 必传，`end_date` 留空由后端按套餐时长计算（duration=0 即终生）。
5. **Cookie 筛选**：后端列表不支持 status 参数，iOS 与 Android 一致做本地过滤。
6. **套餐接口**返回的是 `{status, data:[...]}` 包装（非 `{code,msg,data}`），客户端已分开处理。

## 已知限制

- 图表用 Swift Charts（iOS 16+），更低系统需降级替换。
- AI Key「测试」按钮与后端一致为异步执行，仅提示完成/失败。
- 未做推送/离线缓存；token 过期后接口会返回 401，重新登录即可。
