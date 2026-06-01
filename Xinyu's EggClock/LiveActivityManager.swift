//
//  LiveActivityManager.swift
//  EggClock
//
//  灵动岛 / 锁屏 Live Activity 管理器
//

import ActivityKit
import SwiftUI

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    /// 当前活跃的 Live Activity ID（用于跨 Task 引用）
    private var currentActivityID: String?

    private init() {}

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// 查找当前活动的 Activity 实例
    private func findCurrentActivity() -> Activity<EggClockActivityAttributes>? {
        guard let id = currentActivityID else { return nil }
        return Activity<EggClockActivityAttributes>.activities.first { $0.id == id }
    }

    // MARK: - 开始计时
    func startActivity(eggName: String, eggEmoji: String, total: Int) {
        guard areActivitiesEnabled else {
            print("⚠️ Live Activities 未启用，请在设置中开启")
            return
        }

        // 结束旧 Activity（同步清理引用）
        endActivity(waitForDismiss: false)

        let endTime = Date().addingTimeInterval(TimeInterval(total))
        let attributes = EggClockActivityAttributes(eggName: eggName, eggEmoji: eggEmoji)
        let contentState = EggClockActivityAttributes.ContentState(
            elapsed: 0,
            total: total,
            progress: 0.0,
            hintText: "🔥 正在煮 \(eggName)",
            timerState: "running",
            endTime: endTime
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            currentActivityID = activity.id
        } catch {
            print("❌ 启动 Live Activity 失败: \(error)")
        }
    }

    // MARK: - 更新进度（每秒调用一次）
    func updateActivity(elapsed: Int, total: Int, hintText: String, timerState: String) {
        guard let activity = findCurrentActivity() else { return }

        let progress = total > 0 ? min(1.0, Double(elapsed) / Double(total)) : 0.0
        let remaining = max(0, total - elapsed)
        let endTime = Date().addingTimeInterval(TimeInterval(remaining))

        let contentState = EggClockActivityAttributes.ContentState(
            elapsed: elapsed,
            total: total,
            progress: progress,
            hintText: hintText,
            timerState: timerState,
            endTime: endTime
        )

        Task {
            await activity.update(ActivityContent(state: contentState, staleDate: nil))
        }
    }

    // MARK: - 暂停
    func pauseActivity(eggName: String, elapsed: Int, total: Int) {
        guard let activity = findCurrentActivity() else { return }
        let remaining = max(0, total - elapsed)
        let endTime = Date().addingTimeInterval(TimeInterval(remaining))

        let contentState = EggClockActivityAttributes.ContentState(
            elapsed: elapsed,
            total: total,
            progress: total > 0 ? min(1.0, Double(elapsed) / Double(total)) : 0.0,
            hintText: "⏸ \(eggName) 已暂停",
            timerState: "paused",
            endTime: endTime
        )

        Task {
            await activity.update(ActivityContent(state: contentState, staleDate: nil))
        }
    }

    // MARK: - 恢复
    func resumeActivity(eggName: String, eggEmoji: String, elapsed: Int, total: Int) {
        guard let activity = findCurrentActivity() else { return }
        let remaining = max(0, total - elapsed)
        let endTime = Date().addingTimeInterval(TimeInterval(remaining))

        let contentState = EggClockActivityAttributes.ContentState(
            elapsed: elapsed,
            total: total,
            progress: total > 0 ? min(1.0, Double(elapsed) / Double(total)) : 0.0,
            hintText: "🔥 继续煮 \(eggName)",
            timerState: "running",
            endTime: endTime
        )

        Task {
            await activity.update(ActivityContent(state: contentState, staleDate: nil))
        }
    }

    // MARK: - 结束计时
    func endActivity(waitForDismiss: Bool = true) {
        guard let activity = findCurrentActivity() else { return }

        // 立即清除引用（不等 Task 完成）
        currentActivityID = nil

        // ⚠️ endTime = Date() 而非 nil，否则 Widget 端 remaining=0-0=0 显示 "0:00"
        let finalState = EggClockActivityAttributes.ContentState(
            elapsed: 0,
            total: 0,
            progress: 1.0,
            hintText: "✅ 煮蛋完成",
            timerState: "done",
            endTime: Date()
        )

        let dismissPolicy: ActivityUIDismissalPolicy = waitForDismiss ? .default : .immediate

        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: dismissPolicy
            )
        }
    }
}
