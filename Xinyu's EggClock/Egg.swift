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

// MARK: - 煮蛋统计
private let totalSecondsKey = "EggClock.stats.totalSeconds"

var totalSeconds: Int {
    get { UserDefaults.standard.integer(forKey: totalSecondsKey) }
    set { UserDefaults.standard.set(newValue, forKey: totalSecondsKey) }
}

extension Egg {
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
}
