//
//  EggShortcuts.swift
//  EggClock
//
//  Siri 快捷指令支持
//

import AppIntents
import SwiftUI

// MARK: - App Shortcuts Provider（全局快捷指令）
@available(iOS 16.0, *)
struct EggClockShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartBoilingIntent(),
            phrases: [
                "开始煮蛋 with \(.applicationName)",
                "帮我煮蛋 with \(.applicationName)",
                "计时煮蛋 with \(.applicationName)"
            ],
            shortTitle: "煮蛋",
            systemImageName: "flame.fill"
        )
    }
}

// MARK: - 开始煮蛋意图
@available(iOS 16.0, *)
struct StartBoilingIntent: AppIntent {
    static var title: LocalizedStringResource = "开始煮蛋"
    static var description = IntentDescription("在 EggClock 中开始计时煮蛋")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "蛋种名称", default: "溏心蛋")
    var eggName: String

    init() {}

    init(eggName: String) {
        self.eggName = eggName
    }

    static var parameterSummary: some ParameterSummary {
        Summary("煮 \(\.$eggName)")
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: .startEggTimer,
                object: nil,
                userInfo: ["eggName": eggName]
            )
        }
        return .result()
    }
}

