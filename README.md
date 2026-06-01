# 🍳 Xinyu's EggClock

> 煮蛋计时器 · SwiftUI + Live Activity（灵动岛 / 锁屏实时活动）

## 功能

- 🕐 **四种预设模式**：温泉蛋（8min）、溏心蛋（10min）、常规蛋（18min）、煮到烂（20min）
- ✏️ **自定义食材**：增删自定义蛋类型（名称 / emoji / 时长）
- 🔔 **后台通知**：计时完成自动提醒
- 📊 **煮蛋统计**：累计时长与次数
- 🎯 **灵动岛 / 锁屏 Live Activity**：倒计时实时显示在灵动岛和锁屏
- 🎨 **iOS 17+ SwiftUI**：简洁现代 UI，暖黄色主题

## 技术栈

- SwiftUI（iOS 17+）
- XcodeGen 项目管理
- ActivityKit（Live Activity）
- UserNotifications（后台通知）
- AppIntents（Siri 快捷指令）
- UserDefaults 持久化

## 项目结构

```
Xinyu's EggClock/
├── ContentView.swift           # 主界面 + 计时逻辑
├── Egg.swift                   # 数据模型 + UserDefaults 持久化
├── EggEditorView.swift         # 自定义食材编辑器
├── LiveActivityManager.swift   # 灵动岛 / Live Activity 管理器
├── NotificationManager.swift   # 后台通知
├── EggShortcuts.swift          # Siri 快捷指令
├── SceneDelegate.swift         # SwiftUI 入口
├── AppDelegate.swift           # App 生命周期
├── Shared/
│   └── EggClockActivityAttributes.swift  # Activity 数据结构（主App + Widget 共用）
├── EggClockWidget/             # Widget Extension（Live Activity UI）
│   ├── EggClockWidgetBundle.swift
│   └── Info.plist
└── Assets.xcassets/            # 图标 + 资源
```

## 构建

```bash
cd "/Users/xinyu/Desktop/Xcode folder/Xinyu's App2"
xcodegen generate
xcodebuild -project EggClock.xcodeproj -scheme EggClock \
  -destination 'platform=iOS,id=00008150-000A1C363C38401C' \
  DEVELOPMENT_TEAM=JG859Y62DP \
  -allowProvisioningUpdates CODE_SIGN_STYLE=Automatic build
```

## GitHub

- 仓库：https://github.com/QianXinyu8888/Xinyu-s-EggClock
- Team ID：`JG859Y62DP`
- Bundle ID：`com.xinyu.eggclock`（主App）/ `com.xinyu.eggclock.widget`（Widget Extension）
