//
//  Egg.swift
//  EggClock
//
//  蛋的数据模型 + UserDefaults 持久化
//

import Foundation

struct Egg: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var emoji: String
    var durationSeconds: Int
    var warningSeconds: Int

    init(id: UUID = UUID(), name: String, emoji: String, durationSeconds: Int, warningSeconds: Int) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.durationSeconds = durationSeconds
        self.warningSeconds = warningSeconds
    }

    // MARK: - 内置蛋（不可删除）
    static let builtIn: [Egg] = [
        Egg(name: "温泉蛋", emoji: "🐣", durationSeconds: 480,  warningSeconds: 432),
        Egg(name: "溏心蛋", emoji: "🍳", durationSeconds: 600,  warningSeconds: 540),
        Egg(name: "常规蛋", emoji: "🥚", durationSeconds: 1080, warningSeconds: 972),
        Egg(name: "煮到烂", emoji: "🤮", durationSeconds: 1200, warningSeconds: 1080)
    ]
}

// MARK: - UserDefaults 持久化
extension Egg {
    private static let customEggsKey = "EggClock.customEggs"

    static var customEggs: [Egg] {
        get {
            guard let data = UserDefaults.standard.data(forKey: customEggsKey),
                  let eggs = try? JSONDecoder().decode([Egg].self, from: data) else {
                return []
            }
            return eggs
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: customEggsKey)
            }
        }
    }

    static var allEggs: [Egg] { builtIn + customEggs }

    static func addCustom(_ egg: Egg) {
        var current = customEggs
        current.append(egg)
        customEggs = current
    }

    static func removeCustom(id: UUID) {
        customEggs = customEggs.filter { $0.id != id }
    }

    static func updateCustom(_ egg: Egg) {
        var current = customEggs
        if let idx = current.firstIndex(where: { $0.id == egg.id }) {
            current[idx] = egg
            customEggs = current
        }
    }
}

extension Egg {
    private static let totalSecondsKey = "EggClock.stats.totalSeconds"
    private static let hasSentWarningKey = "EggClock.timer.hasSentWarning"

    /// 本轮计时是否已发过 90% 预警（防止通知重复触发）
    static var hasSentWarning: Bool {
        get { UserDefaults.standard.bool(forKey: hasSentWarningKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasSentWarningKey) }
    }

    /// 重置预警标记（新计时开始时调用）
    static func resetWarningFlag() {
        UserDefaults.standard.removeObject(forKey: hasSentWarningKey)
    }

    static var totalSeconds: Int {
        get { UserDefaults.standard.integer(forKey: totalSecondsKey) }
        set { UserDefaults.standard.set(newValue, forKey: totalSecondsKey) }
    }

    static var totalCount: Int {
        get { UserDefaults.standard.integer(forKey: "EggClock.stats.totalCount") }
        set { UserDefaults.standard.set(newValue, forKey: "EggClock.stats.totalCount") }
    }

    /// 累计总烹饪时长（秒）
    static var totalMinutes: Int { totalSeconds / 60 }

    /// 格式化总时长显示
    static var formattedTotalTime: String {
        let total = totalSeconds
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    static func recordBoiling(seconds: Int) {
        totalCount += 1
        totalSeconds += seconds
    }

    // MARK: - 计时器持久化（App 被终止后冷启动恢复）
    private static let timerEndTimeKey     = "EggClock.timer.endTime"
    private static let timerPausedElapsedKey = "EggClock.timer.pausedElapsed"
    private static let timerEggIdKey        = "EggClock.timer.eggId"
    private static let timerEggNameKey      = "EggClock.timer.eggName"
    private static let timerEggEmojiKey     = "EggClock.timer.eggEmoji"
    private static let timerTotalKey        = "EggClock.timer.total"

    /// 持久化保存当前计时器状态（App 进入后台时调用）
    static func saveTimerPersistentState(
        endTime: Date,
        pausedElapsed: Int,
        egg: Egg
    ) {
        let defaults = UserDefaults.standard
        defaults.set(endTime.timeIntervalSince1970, forKey: timerEndTimeKey)
        defaults.set(pausedElapsed, forKey: timerPausedElapsedKey)
        defaults.set(egg.id.uuidString, forKey: timerEggIdKey)
        defaults.set(egg.name, forKey: timerEggNameKey)
        defaults.set(egg.emoji, forKey: timerEggEmojiKey)
        defaults.set(egg.durationSeconds, forKey: timerTotalKey)
    }

    /// 清除持久化的计时器状态（计时结束/主动停止时调用）
    static func clearTimerPersistentState() {
        let defaults = UserDefaults.standard
        [timerEndTimeKey, timerPausedElapsedKey, timerEggIdKey,
         timerEggNameKey, timerEggEmojiKey, timerTotalKey].forEach { defaults.removeObject(forKey: $0) }
    }

    /// 尝试恢复持久化的计时器状态（返回恢复所需数据，或 nil）
    static func loadTimerPersistentState() -> (
        endTime: Date, pausedElapsed: Int, eggName: String,
        eggEmoji: String, total: Int
    )? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: timerEndTimeKey) != nil else { return nil }
        guard let endTimeInterval = defaults.object(forKey: timerEndTimeKey) as? TimeInterval else { return nil }
        let pausedElapsed = defaults.integer(forKey: timerPausedElapsedKey)
        let eggName = defaults.string(forKey: timerEggNameKey) ?? ""
        let eggEmoji = defaults.string(forKey: timerEggEmojiKey) ?? "🍳"
        let total = defaults.integer(forKey: timerTotalKey)
        return (Date(timeIntervalSince1970: endTimeInterval), pausedElapsed, eggName, eggEmoji, total)
    }
}
