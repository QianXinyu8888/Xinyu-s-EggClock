//
//  EggClockWidgetBundle.swift
//  EggClockWidget
//
//  Widget Extension - Live Activity
//  设计原则：所有 UI 元素均基于 endTime 绝对时间戳计算
//  App 被杀 / 退后台后，倒计时 / 进度条 / 百分比 均持续准确
//

import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - 颜色扩展（统一使用亮色系，确保暗黑模式下清晰可见）

extension Color {
    /// 主文字：接近纯白
    static let eggPrimary = Color(red: 0.98, green: 0.98, blue: 1.0)
    /// 次要文字
    static let eggSecondary = Color(red: 0.75, green: 0.77, blue: 0.82)
    /// 极淡文字（用于标签前缀等）
    static let eggMuted = Color(red: 0.60, green: 0.62, blue: 0.68)
    /// 暗色模式进度条轨道
    static let eggTrack = Color(red: 0.22, green: 0.22, blue: 0.26)
    /// 暗色模式标签背景
    static let eggPillBg = Color(red: 0.28, green: 0.28, blue: 0.33)
}

// MARK: - 工具函数

/// 格式化秒数 → "Nmin Ss"（例：12min 3s），s=0 时省略秒
fileprivate func formatMinSec(_ totalSeconds: Int) -> String {
    let m = totalSeconds / 60
    let s = totalSeconds % 60
    if s == 0 { return "\(m)min" }
    return "\(m)min \(s)s"
}

/// 根据 elapsed/total 实时计算 progress（删除了 ContentState.progress 字段后改用此函数）
fileprivate func computeProgress(elapsed: Int, total: Int) -> Double {
    guard total > 0 else { return 0 }
    return min(1.0, Double(elapsed) / Double(total))
}

// MARK: - Live Activity

struct EggClockLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EggClockActivityAttributes.self) { context in
            LockScreenView(context: context)
            
        } dynamicIsland: { context in
            return DynamicIsland {
                // ═══════════════════════════════════════════════════════
                //  EXPANDED 展开态 - iOS 标准三栏布局（leading/center/bottom）
                // ═══════════════════════════════════════════════════════
                
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.eggEmoji)
                        .font(.system(size: 22))
                        .padding(.leading, 6)
                }
                
                // ── 实时计算 progress（不再依赖 ContentState.progress）──
                let elapsed = Double(context.state.elapsed)
                let total = Double(context.state.total)
                let progress = computeProgress(elapsed: Int(elapsed), total: Int(total))
                let remaining = max(0.0, total - elapsed)
                
                // 根据进度计算当前阶段
                let phaseColor: Color = progress < 0.25 ? .yellow : (progress < 0.6 ? .orange : (progress < 0.9 ? .red : .green))
                let phaseLabel: String = progress < 0.25 ? "溏心" : (progress < 0.6 ? "微溏" : (progress < 0.9 ? "全熟" : "完成"))
                
                DynamicIslandExpandedRegion(.center) {
                    HStack(alignment: .center, spacing: 0) {
                        // 左侧：emoji + 蛋名
                        HStack(spacing: 5) {
                            Text(context.attributes.eggEmoji)
                                .font(.system(size: 20))
                            Text(context.attributes.eggName)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.eggPrimary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // 中间：倒计时（系统驱动，实时刷新）
                        if remaining > 0, let endTime = context.state.endTime {
                            Text(endTime, style: .timer)
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundStyle(Color.eggPrimary)
                                .contentTransition(.numericText())
                        } else {
                            Text("✅ 完成")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundStyle(.green)
                        }
                        
                        Spacer()
                        
                        // 右侧：当前状态 pill
                        HStack(spacing: 4) {
                            Text("当前状态：")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(Color.eggMuted)
                            Circle()
                                .fill(phaseColor)
                                .frame(width: 5, height: 5)
                            Text(phaseLabel)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(phaseColor)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.eggPillBg)
                        )
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.eggTrack)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [phaseColor.opacity(0.8), phaseColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(2, geo.size.width * progress))
                                .shadow(color: phaseColor.opacity(0.5), radius: 3, x: 0, y: 0)
                        }
                    }
                    .frame(height: 6)
                    .clipShape(Capsule())
                    .padding(.horizontal, 8)
                    .padding(.bottom, 3)
                }
                
            // ═══════════════════════════════════════════════════════
            //  COMPACT 紧凑态
            // ═══════════════════════════════════════════════════════
            } compactLeading: {
                HStack(spacing: 5) {
                    Text(context.attributes.eggEmoji)
                        .font(.system(size: 15))
                    
                    // 蛋名优先显示，不截断
                    Text(context.attributes.eggName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.eggPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
            } compactTrailing: {
                let remaining = max(0.0, context.state.endTime?.timeIntervalSinceNow ?? 0.0)
                let total = Double(context.state.total)
                let progress = total > 0 ? min(1.0, (Double(context.state.total) - remaining) / total) : 0.0
                let phaseColor: Color = progress < 0.25 ? .yellow : (progress < 0.6 ? .orange : (progress < 0.9 ? .red : .green))
                if remaining > 0, let endTime = context.state.endTime {
                    Text(endTime, style: .timer)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(phaseColor)
                        .contentTransition(.numericText())
                } else {
                    Text("完成")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.green)
                }
                
            // ═══════════════════════════════════════════════════════
            //  MINIMAL 最小态
            // ═══════════════════════════════════════════════════════
            } minimal: {
                let remaining = max(0.0, context.state.endTime?.timeIntervalSinceNow ?? 0.0)
                let total = Double(context.state.total)
                let progress = total > 0 ? min(1.0, (Double(context.state.total) - remaining) / total) : 0.0
                ZStack {
                    Circle()
                        .stroke(Color.eggTrack, lineWidth: 2)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                colors: [.orange, .yellow, .orange],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    Text(context.attributes.eggEmoji)
                        .font(.system(size: 10))
                }
                .frame(width: 24, height: 24)
            }
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    let context: ActivityViewContext<EggClockActivityAttributes>
    
    var body: some View {
        // ── 实时计算所有数据（每次视图刷新都重新计算）──
        let remaining = max(0.0, context.state.endTime?.timeIntervalSinceNow ?? 0.0)
        let total = Double(context.state.total)
        let elapsed = max(0.0, total - remaining)
        let progress = total > 0 ? min(1.0, elapsed / total) : 0.0
        let phaseColor: Color = progress < 0.25 ? .yellow : (progress < 0.6 ? .orange : (progress < 0.9 ? .red : .green))
        let phaseLabel: String = progress < 0.25 ? "溏心" : (progress < 0.6 ? "微溏" : (progress < 0.9 ? "全熟" : "完成"))
        
        HStack(spacing: 18) {
            // 左侧：emoji 卡片
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                
                Text(context.attributes.eggEmoji)
                    .font(.system(size: 44))
                
                Circle()
                    .fill(phaseColor)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1.5))
                    .offset(x: 26, y: -26)
            }
            
            // 右侧：信息
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(context.attributes.eggName)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(Color.eggPrimary)
                    
                    Spacer()
                    
                    Text(phaseLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(phaseColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.eggPillBg, in: Capsule())
                }
                
                if remaining > 0, let endTime = context.state.endTime {
                    Text(endTime, style: .timer)
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(.orange)
                        .contentTransition(.numericText())
                } else {
                    Text("完成！🔥")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.green)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.eggTrack)
                        Capsule().fill(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(3, geo.size.width * progress))
                        .shadow(color: .orange.opacity(0.5), radius: 5, x: 0, y: 0)
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())
                
                HStack {
                    Text(formatMinSec(Int(elapsed)))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.eggSecondary)
                    
                    Text("/")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.eggMuted)
                    
                    Text(formatMinSec(Int(total)))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.eggMuted)
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(22)
        .activityBackgroundTint(.black.opacity(0.85))
    }
}

// MARK: - Widget Bundle

@main
struct EggClockWidgetBundle: WidgetBundle {
    var body: some Widget {
        EggClockLiveActivity()
    }
}