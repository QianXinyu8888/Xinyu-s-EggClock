//
//  EggClockActivityAttributes.swift
//  EggClock
//
//  Live Activity 数据模型（主 App 和 Widget Extension 共享）
//

import ActivityKit
import Foundation

public struct EggClockActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var elapsed: Int
        public var total: Int
        public var hintText: String
        public var timerState: String
        /// 计时结束时间（用于倒计时显示），nil 表示无倒计时
        public var endTime: Date?

        public init(elapsed: Int, total: Int, hintText: String, timerState: String, endTime: Date? = nil) {
            self.elapsed = elapsed
            self.total = total
            self.hintText = hintText
            self.timerState = timerState
            self.endTime = endTime
        }
    }

    public var eggName: String
    public var eggEmoji: String

    public init(eggName: String, eggEmoji: String) {
        self.eggName = eggName
        self.eggEmoji = eggEmoji
    }
}