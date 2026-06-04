//
//  TimerCoordinator.swift
//  EggClock
//
//  跨层状态桥接：SceneDelegate → ContentView 冷启动通信
//

import Foundation
import Combine

/// 煮蛋意图协调器（支持 Siri Shortcut 冷启动触发）
@MainActor
final class TimerCoordinator: ObservableObject {
    static let shared = TimerCoordinator()

    /// 待执行的蛋名称（由 SceneDelegate 在冷启动时写入，ContentView 读取后清除）
    @Published var pendingEggName: String?

    private init() {}

    /// 写入待执行蛋名（SceneDelegate 调用）
    func setPendingEgg(_ name: String) {
        pendingEggName = name
    }

    /// 消费待执行蛋名（ContentView 调用，消费后清除）
    func consumePendingEgg() -> String? {
        guard let name = pendingEggName else { return nil }
        pendingEggName = nil
        return name
    }
}
