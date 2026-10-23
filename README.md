# 周期提醒（CycleReminder）

一款简洁的 iOS 本地提醒应用：设置起始时间、结束时间（可选）和重复间隔（每 N 天），到点通过本地通知提醒。支持多条规则、暂停 / 恢复、删除，以及多种内置提示铃声。

## 功能

- 多条提醒规则，互不影响
- 每条规则可设置：
  - **提醒内容**：自由文本
  - **起始时间**：日期 + 时间
  - **结束时间**（可选）：到期自动停止，跨度几天、几个月、几年都可以；不设置则一直提醒
  - **重复周期**：每天 / 3 天 / 7 天 / 30 天 / 自定义 1–365 天
  - **提示铃声**：7 种内置 + 系统默认，选择前可试听
- 规则卡片上直接开关（暂停 / 恢复），左滑可删除
- 卡片实时显示下次提醒时间（绝对时间 + 相对时间）、结束时间，到期后标记“已结束”
- 通知权限被关闭时在列表顶部提示，一键跳转系统设置

## 登录

- 账号：`admin`
- 密码：当天的 8 位日期，例如 2026 年 10 月 23 日 → `20261023`
- 每次启动 App 都需要重新登录；主界面左上角 🔒 可随时重新锁定
- 锁定 / 未登录状态下，已设置的提醒通知仍会照常送达（iOS 本地通知的系统行为，通知内容无法按登录状态隐藏）

## 在自己的 iPhone 上真机测试

iPhone 只能安装"编译 + 签名"后的包，编译必须发生在苹果环境。三种路径：

| 路径 | 需要什么 | 说明 |
|---|---|---|
| Mac + 数据线 | 任意一台 Mac + 免费 Apple ID | Xcode 打开工程选真机 `Cmd+R`，10 分钟搞定；免费证书 7 天有效，重新插线点一下即续 |
| 纯 Windows + 数据线（CI 侧载） | GitHub 上的 IPA 产物 + [Sideloadly](https://sideloadly.io)（免费）+ Apple ID | CI 已配置自动产出未签名 IPA：Actions 页下载 `CycleReminder-ipa` → Sideloadly 用你的 Apple ID 签名并装进手机；免费账号限 3 个应用、7 天后需重签；装完在 设置 → 通用 → VPN与设备管理 里信任开发者 |
| TestFlight | $99/年 开发者账号 | 体验最好，但需付费账号并有 Mac/CI 上传构建 |

注意事项：

- 真机系统需 **iOS 16.0 或更高**（工程已适配到 iOS 16；如果你的手机低于 16，告诉我再做进一步适配）
- 侧载版的功能与正式版完全一致：本应用只用本地通知，不依赖推送，侧载后铃声、提醒全部正常
- 首次打开通知权限弹窗请选"允许"

## 环境要求

- 一台 Mac（Xcode 16 或更高版本）
- iOS 16.0+（模拟器或真机；已从 iOS 17 降级适配，支持更多旧机型）

> 本项目在 Windows 上无法编译 iOS 应用，所有代码和工程文件已备好，请把整个目录拷贝到 Mac 上用 Xcode 打开。

## 运行步骤

1. 将整个 `ios` 目录拷贝到 Mac。
2. 双击 `CycleReminder.xcodeproj` 用 Xcode 打开。
3. 顶部选择模拟器（如 iPhone 16），或连接真机（真机需在 Signing & Capabilities 里选择你的 Apple ID / Team）。
4. `Cmd + R` 运行。
5. 第一次保存规则时会请求通知权限，请选择“允许”。

## 在 Windows 上验证编译（无需 Mac）

iOS 模拟器是 Xcode 的组件，只能在 macOS 上运行，Windows 装不了。但**编译验证**可以借助 GitHub 的免费 macOS 服务器完成——仓库已配好工作流（`.github/workflows/ios-build.yml`）和共享 scheme，推上去就会自动编译，能发现所有 Swift 代码错误：

1. 在 GitHub 新建一个**公开**仓库（公开仓库使用标准 macOS runner 构建免费、不计分钟数，本工作流的 `macos-15` 属于标准 runner；私有仓库 macOS 按 $0.062/分钟计费，约为 Linux 的 10 倍）。
2. 在本目录执行并推送：
   ```bash
   git init
   git add .
   git commit -m "CycleReminder initial commit"
   git remote add origin https://github.com/<你的用户名>/<仓库名>.git
   git push -u origin main
   ```
3. 打开仓库的 **Actions** 标签页，等 "iOS Build Check" 跑完：绿色 ✔ = 代码可编译；红色 ✘ = 点进去看日志，报错行号一清二楚，修完再 push 重跑。

注意：CI 只能编译验证。**交互式调试**（在模拟器里点界面、打断点）需要 Xcode 图形界面，只有三条路：真 Mac、云 Mac（MacinCloud / MacStadium 等，约 $1/小时，远程桌面里就是完整的 Xcode + 模拟器）、或在 Windows 虚拟机里装 macOS（违反 Apple 许可协议且稳定性差，不推荐）。

## 自动测试

已内置 13 个 XCTest 单元测试（`CycleReminderTests/`），寄宿在 App 进程中运行（测试通过即证明 App 能在模拟器正常启动）：

- **排期算法**（8 项）：未来/过去起始时间的顺延、每天周期、结束时间截断（含边界当天）、已到期、周期大于剩余跨度、跨年提醒时刻不漂移、数量上限
- **登录规则**（5 项）：当天 8 位日期密码、账号大小写与空格容错、错误密码/账号/昨日密码拒绝、登录状态切换

运行方式：

- 本地（Mac）：Xcode 打开工程，`Cmd + U`
- 云端（Windows 即可）：推送到 GitHub，CI 自动执行 `xcodebuild test`，在 Actions 页看结果

另外 `tools/verify_logic.js`（`node tools/verify_logic.js`）是同一套算法在 Node 下的独立复算（18 项断言），与 XCTest 互相印证，可在 Windows 上直接跑。

## 通知机制说明

- 规则保存后会立即注册本地通知；应用每次回到前台也会自动重排，保证长期计划持续有效（跨年的规则同样如此）。
- iOS 的重复触发器无法表达“首次在 X 时刻、之后每 N 天”的相位，因此采用**逐次精确排期**：每条规则最多预先排入未来 16 次提醒，全应用最多同时挂起 60 条（系统上限 64 条）。只要偶尔打开一下 App，后续提醒就会被自动续排。
- 起始时间已过时，提醒自动从下一个周期开始；结束时间之后的提醒点会被自动过滤。
- 时间推算使用 `Calendar` 按天进位，跨夏令时提醒时刻不漂移。
- 修改系统时间等极端情况可能导致计划偏差，重新打开 App 即可校正。

## 自定义铃声

1. 准备一个 ≤ 30 秒的音频文件，推荐 44.1kHz / 16bit PCM 的 `.wav` 或 `.caf`，放入 `CycleReminder/Sounds/`。
2. 打开 `CycleReminder/Models/SoundCatalog.swift`，在 `all` 数组里加一行，例如：
   `SoundOption(id: "mine", fileName: "mine.wav", displayName: "我的铃声")`
3. 重新运行 App，编辑页即可选择并试听。

## 重新生成资源（可选）

`tools/make_sounds.js` 与 `tools/make_icon.js` 用于生成内置铃声和应用图标（需要 Node.js 18+，无第三方依赖）。仓库中已包含生成结果，通常无需重新运行。

```bash
node tools/make_sounds.js
node tools/make_icon.js
```

## 项目结构

```
ios/
├─ CycleReminder.xcodeproj/        # Xcode 工程描述（Xcode 16+ 文件夹同步格式）
├─ CycleReminder/                  # 应用源码与资源
│  ├─ CycleReminderApp.swift       # 入口，前台时自动续排通知
│  ├─ Models/                      # 规则模型、铃声目录
│  ├─ Store/                       # 规则存储（JSON 持久化，单一数据源）
│  ├─ Services/                    # 通知调度、铃声试听
│  ├─ Views/                       # 界面（规则列表、编辑表单）
│  ├─ Assets.xcassets/             # 图标与主题色
│  └─ Sounds/                      # 内置提示铃声（WAV）
├─ CycleReminderTests/             # 单元测试（排期算法、登录规则）
└─ tools/                          # 资源生成与逻辑验证脚本（Node.js）
```

## 常见问题

- **收不到通知？** 检查 系统设置 → 通知 → 周期提醒 是否允许；模拟器上通知横幅会正常弹出。
- **删除 / 暂停的规则还会响吗？** 不会，任何变更都会立即重建通知计划。
- **跨度几年的规则会一直有效吗？** 会。每条规则预排未来 16 次，每次打开 App 自动续排；长时间（超过预排窗口）不打开 App 的话，中间的提醒点会缺失，打开一次即恢复。
- **支持每天多次或按小时提醒吗？** 当前版本以“天”为最小周期。
