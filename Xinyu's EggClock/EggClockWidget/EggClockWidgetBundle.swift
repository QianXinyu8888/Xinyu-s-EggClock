//
//  EggClockWidgetBundle.swift
//  EggClockWidget
//
//  Widget Extension - Live Activity
//

import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Live Activity UI
struct EggClockLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EggClockActivityAttributes.self) { context in
            // ── 锁屏/横幅 UI ──────────────────────────────────
            LockScreenView(context: context)

        } dynamicIsland: { context in
            // ── 灵动岛 UI ──────────────────────────────────────
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .center, spacing: 2) {
                        Text(context.attributes.eggEmoji)
                            .font(.system(size: 30))
                        if context.state.timerState == "paused" {
                            Text("暂停")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.orange)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 3) {
                        if let endTime = context.state.endTime {
                            let remaining = max(0, Int(endTime.timeIntervalSinceNow))
                            Text(countdownText(remaining))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(context.state.timerState == "paused" ? .orange : .white)
                                .contentTransition(.numericText())
                        } else {
                            Text("\(context.state.total - context.state.elapsed)s")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                        }
                        Text("煮 \(context.attributes.eggName)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        // 进度环形
                        ZStack {
                            Circle()
                                .stroke(.ultraThinMaterial, lineWidth: 3)
                            Circle()
                                .trim(from: 0, to: context.state.progress)
                                .stroke(.orange, lineWidth: 3)
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 32, height: 32)
                        .overlay {
                            if context.state.progress > 0 {
                                Text("\(Int(context.state.progress * 100))%")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text("\(context.state.elapsed)s")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        // 进度条
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.ultraThinMaterial)
                                Capsule().fill(
                                    LinearGradient(
                                        colors: [.orange, .yellow],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, geo.size.width * context.state.progress))
                            }
                        }
                        .frame(height: 6)
                        .clipShape(Capsule())

                        HStack {
                            Text(context.state.hintText)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let endTime = context.state.endTime {
                                let remaining = max(0, Int(endTime.timeIntervalSinceNow))
                                Text(remaining > 0
                                     ? "完成于 \(endTime, style: .time)"
                                     : "✅ 已完成")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.orange)
                                    .monospacedDigit()
                            } else {
                                Text("✅ 已完成")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                ZStack {
                    Circle()
                        .stroke(.ultraThinMaterial, lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(.orange, lineWidth: 2)
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 16, height: 16)
                .overlay {
                    Text(context.attributes.eggEmoji)
                        .font(.system(size: 8))
                }
            } compactTrailing: {
                if let endTime = context.state.endTime {
                    let remaining = max(0, Int(endTime.timeIntervalSinceNow))
                    Text(countdownText(remaining))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(context.state.timerState == "paused" ? .orange : .white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                } else {
                    Text("\(context.state.total - context.state.elapsed)s")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }
            } minimal: {
                ZStack {
                    Circle()
                        .stroke(.ultraThinMaterial, lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(.orange, lineWidth: 2)
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 12, height: 12)
                .overlay {
                    Text(context.attributes.eggEmoji)
                        .font(.system(size: 7))
                }
            }
        }
    }

    private func countdownText(_ seconds: Int) -> String {
        if seconds <= 0 {
            return "完成!"
        }
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Lock Screen View
struct LockScreenView: View {
    let context: ActivityViewContext<EggClockActivityAttributes>

    private var remainingSeconds: Int {
        guard let endTime = context.state.endTime else {
            return context.state.total - context.state.elapsed
        }
        return max(0, Int(endTime.timeIntervalSinceNow))
    }

    var body: some View {
        HStack(spacing: 14) {
            // emoji 大标
            Text(context.attributes.eggEmoji)
                .font(.system(size: 40))
                .frame(width: 56, height: 56)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("🥚 煮 \(context.attributes.eggName)")
                        .font(.system(size: 15, weight: .bold))
                    Spacer()
                    // 倒计时大字
                    Text(countdownText(remainingSeconds))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }

                // 进度条
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.ultraThinMaterial)
                        Capsule().fill(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * context.state.progress))
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())

                HStack {
                    Text("\(context.state.elapsed)s → \(context.state.total)s")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if context.state.timerState == "paused" {
                        Text("⏸ 已暂停")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.orange)
                    } else {
                        if let endTime = context.state.endTime {
                            Text("完成于 \(endTime, style: .time)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .activityBackgroundTint(.black.opacity(0.6))
    }

    private func countdownText(_ seconds: Int) -> String {
        if seconds <= 0 {
            return "完成!"
        }
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Widget Bundle Entry
@main
struct EggClockWidgetBundle: WidgetBundle {
    var body: some Widget {
        EggClockLiveActivity()
    }
}