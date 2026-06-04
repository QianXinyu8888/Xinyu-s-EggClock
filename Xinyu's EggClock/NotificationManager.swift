//
//  NotificationManager.swift
//  EggClock
//
//  后台通知管理
//

import UserNotifications
import UIKit

enum NotificationManager {
    static let center = UNUserNotificationCenter.current()

    static func request() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print("🔔 通知权限: \(granted ? "已授权" : "拒绝")")
        }
    }

    static func sendDoneNotification(eggName: String) {
        let content = UNMutableNotificationContent()
        content.title = "🍳 Xinyu's EggClock"
        content.body = "\(eggName) 煮好了！可以关火了 ✅"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: "egg-done", content: content, trigger: nil)
        center.add(request)
    }

    static func sendWarningNotification(eggName: String) {
        let content = UNMutableNotificationContent()
        content.title = "🔥 即将完成"
        content.body = "\(eggName) 快煮好了，准备关火！"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: "egg-warning", content: content, trigger: nil)
        center.add(request)
    }

    static func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    static func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
