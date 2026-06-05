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

    /// 查找当前活动的 Activity 实例（Activity 列表可能已被系统清理，防御式返回 nil）
    private func findCurrentActivity() -> Activity<EggClockActivityAttributes>? {
        guard let id = currentActivityID else { return nil }
        guard let activity = Activity<EggClockActivityAttributes>.activities.first(where: { $0.id == id }) else {
            // Activity 已被系统移除，清除本地缓存的 ID
            currentActivityID = nil
            return nil
        }
        return activity
    }

    // MARK: - 开始计时
    /// - Parameters:
    ///   - initialElapsed: 冷启动恢复时传入已用秒数，默认 0
    ///   - endTimeOverride: 冷启动恢复时传入已有的 endTime，默认由 total 计算
    func startActivity(eggName: String, eggEmoji: String, total: Int,
                       initialElapsed: Int = 0, endTimeOverride: Date? = nil) {
        guard areActivitiesEnabled else {
            print("⚠️ Live Activities 未启用，请在设置中开启")
            return
        }

        // 结束旧 Activity（同步清理引用）
        endActivity(waitForDismiss: false)

        let elapsed = initialElapsed
        let endTime = endTimeOverride ?? Date().addingTimeInterval(TimeInterval(total - elapsed))
        let attributes = EggClockActivityAttributes(eggName: eggName, eggEmoji: eggEmoji)
        let contentState = EggClockActivityAttributes.ContentState(
            elapsed: elapsed,
            total: total,
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
    /// - Parameters:
    ///   - endTimeOverride: 手动指定结束时间（用于后台恢复时同步 LiveActivity 时钟）
    func updateActivity(
        elapsed: Int,
        total: Int,
        hintText: String,
        timerState: String,
        endTimeOverride: Date? = nil
    ) {
        guard let activity = findCurrentActivity() else { return }

        let endTime: Date
        if let override = endTimeOverride {
            endTime = override
        } else {
            let remaining = max(0, total - elapsed)
            endTime = Date().addingTimeInterval(TimeInterval(remaining))
        }

        let contentState = EggClockActivityAttributes.ContentState(
            elapsed: elapsed,
            total: total,
            hintText: hintText,
            timerState: timerState,
            endTime: endTime
        )

        // staleDate = nil 让 iOS 自行根据 endTime 持续刷新 Dynamic Island
        // 如果不设 nil，iOS 会在 endTime + 60s 时认为内容过时而停止刷新
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

        // 从 endTime 计算最终 elapsed（不再依赖每秒更新的 stale 值）
        let state = activity.content.state
        let remaining = max(0, Int((state.endTime ?? Date()).timeIntervalSinceNow))
        let finalElapsed = max(0, state.total - remaining)
        let finalTotal = state.total
        let finalState = EggClockActivityAttributes.ContentState(
            elapsed: finalElapsed,
            total: finalTotal,
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