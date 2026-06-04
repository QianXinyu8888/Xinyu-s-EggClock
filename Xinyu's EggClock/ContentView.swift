//
//  ContentView.swift
//  EggClock
//
//  主界面
//

import SwiftUI
import Combine
import AudioToolbox

// MARK: - 触感反馈管理器
private enum HapticsManager {
    // 静态引用，避免generator被dealloc导致haptic不触发
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// 按钮轻触（Gemini 发消息同款）
    static func lightTap() {
        lightGenerator.prepare()
        lightGenerator.impactOccurred()
    }
    /// 计时完成 / 成功
    static func success() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
    }
    /// 90% 预警（警告）
    static func warning() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.warning)
    }
}

// MARK: - 工具函数
private func formatMinSec(_ totalSeconds: Int) -> String {
    let m = totalSeconds / 60
    let s = totalSeconds % 60
    if s == 0 { return "\(m)min" }
    return "\(m)min \(s)s"
}

extension Notification.Name {
    static let startEggTimer = Notification.Name("startEggTimer")
}

struct ContentView: View {
    @State private var selectedEgg: Egg?
    @State private var elapsed: Int = 0
    @State private var timerState: TimerState = .idle
    @State private var timerCancellable: AnyCancellable?
    @State private var customEggs: [Egg] = []
    @State private var showEditor = false
    @State private var editingEgg: Egg?
    @State private var showStats = false

    // ── 后台计时修复：基于 Date 计算经过时间 ──────────────────────────────
    @State private var timerStartTime: Date?        // 本轮计时启动时刻
    @State private var pausedElapsed: Int = 0       // 暂停时已累计的秒数
    @State private var lastRestoreTime: Date?       // 上次恢复时间（防通知乱序重复触发）

    // ── Siri Shortcut 冷启动支持 ──────────────────────────────────────────
    @StateObject private var coordinator = TimerCoordinator.shared
    @State private var isUserPaused = false  // true=用户主动暂停 false=App后台挂起

    private let bgYellow = Color(red: 1.0, green: 0.84, blue: 0.0)

    var body: some View {
        ZStack {
            bgYellow.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                builtInEggs
                customEggsSection
                Spacer()
                timerDisplay
            }
        }
        .animation(.easeInOut(duration: 0.25), value: timerState)
        .onAppear {
            customEggs = Egg.customEggs
            NotificationManager.request()
            setupIntentListener()

            // 冷启动时：检查是否有 Siri Shortcut 写入的待执行蛋
            if let pendingName = coordinator.consumePendingEgg() {
                let allEggs = Egg.builtIn + Egg.customEggs
                if let egg = allEggs.first(where: { $0.name == pendingName }) {
                    selectEgg(egg)
                    return
                }
            }

            // 冷启动恢复：检查是否有被系统杀 App 前保存的计时器状态
            if timerState == .idle, let saved = Egg.loadTimerPersistentState() {
                let now = Date()
                let remaining = max(0, Int(saved.endTime.timeIntervalSince(now)))
                let totalElapsed = saved.pausedElapsed + (saved.total - saved.pausedElapsed) - remaining

                if totalElapsed >= 0 && totalElapsed < saved.total {
                    // 计时还未结束——重建计时器状态（不调用 selectEgg，避免重置+双Timer）
                    let allEggs = Egg.builtIn + Egg.customEggs
                    if let egg = allEggs.first(where: { $0.name == saved.eggName }) {
                        // 直接赋值状态，不走 selectEgg
                        selectedEgg = egg
                        pausedElapsed = totalElapsed
                        elapsed = totalElapsed
                        // timerStartTime 必须回拨：往回拨 totalElapsed 秒，使得 computeElapsed() 正确
                        timerStartTime = now.addingTimeInterval(-TimeInterval(totalElapsed))
                        timerState = .running
                        isUserPaused = false

                        // 重建 LiveActivity（一次性传入正确状态，避免首次 update 触发展开）
                        let newEndTime = now.addingTimeInterval(TimeInterval(saved.total - totalElapsed))
                        LiveActivityManager.shared.startActivity(
                            eggName: egg.name,
                            eggEmoji: egg.emoji,
                            total: egg.durationSeconds,
                            initialElapsed: totalElapsed,
                            endTimeOverride: newEndTime
                        )

                        // 启动计时器（只启动一次）
                        startTimer()
                    }
                } else {
                    // 计时已结束——清除残留状态
                    Egg.clearTimerPersistentState()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            saveTimerState()         // 进入后台时保存当前已用时间
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            restoreTimerIfNeeded()   // 回到前台时恢复计时
        }
        .sheet(isPresented: $showEditor) {
            EggEditorView(
                existingEgg: editingEgg,
                onSave: { egg in
                    if editingEgg != nil {
                        Egg.updateCustom(egg)
                    } else {
                        Egg.addCustom(egg)
                    }
                    customEggs = Egg.customEggs
                },
                onDelete: { egg in
                    Egg.removeCustom(id: egg.id)
                    customEggs = Egg.customEggs
                    if selectedEgg?.id == egg.id { resetTimer() }
                }
            )
        }
        .sheet(isPresented: $showStats) {
            StatsView()
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            Text("Xinyu's EggClock")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.88))

            Spacer()

            Button { showStats = true } label: {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.black.opacity(0.6))
            }

            Button {
                editingEgg = nil
                showEditor = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.black.opacity(0.7))
            }
            .padding(.leading, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    // MARK: - Built-in Eggs
    private var builtInEggs: some View {
        VStack(spacing: 14) {
            ForEach(Egg.builtIn) { egg in
                EggRowButton(
                    egg: egg,
                    isActive: selectedEgg?.id == egg.id && timerState == .running,
                    isDone: selectedEgg?.id == egg.id && timerState == .done,
                    isCustom: false,
                    onTap: { highlightEgg(egg) }
                )
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Custom Eggs
    @ViewBuilder
    private var customEggsSection: some View {
        if !customEggs.isEmpty {
            VStack(spacing: 14) {
                ForEach(customEggs) { egg in
                    EggRowButton(
                        egg: egg,
                        isActive: selectedEgg?.id == egg.id && timerState == .running,
                        isDone: selectedEgg?.id == egg.id && timerState == .done,
                        isCustom: true,
                        onTap: { highlightEgg(egg) },
                        onEdit: {
                            editingEgg = egg
                            showEditor = true
                        }
                    )
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteCustomEgg(egg)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
        }
    }

    // MARK: - Timer Display
    private var timerDisplay: some View {
        VStack(spacing: 12) {
            // 暂停 / 终止按钮（运行中或暂停时出现）
            if timerState == .running || timerState == .paused {
                HStack(spacing: 32) {
                    Button {
                        HapticsManager.lightTap()
                        pauseTimer()
                    } label: {
                        Image(systemName: timerState == .paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(Color(red: 1.0, green: 0.97, blue: 0.88)))
                            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    }
                    Button {
                        HapticsManager.lightTap()
                        stopTimer()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 72)
                            .background(Circle().fill(Color.red.opacity(0.7)))
                            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }

            // 核心计时区
            if let egg = selectedEgg {
                switch timerState {
                case .running, .paused:
                    runningTimerView(egg: egg)
                case .done:
                    doneView(egg: egg)
                case .idle:
                    idleSelectedView(egg: egg)
                }
            } else {
                emptySelectionView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: timerState)
        .padding(.bottom, 60)
    }

    // MARK: - Timer Sub-Views
    private func runningTimerView(egg: Egg) -> some View {
        VStack(spacing: 6) {
            Text(egg.emoji)
                .font(.system(size: 40))
                .opacity(timerState == .paused ? 0.45 : 1.0)

            Text("\(formatMinSec(elapsed)) / \(formatMinSec(egg.durationSeconds))")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 1.0, green: 0.97, blue: 0.88)))
                .contentTransition(.numericText())

            Text(hintText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.black.opacity(0.55))
        }
    }

    private func doneView(egg: Egg) -> some View {
        VStack(spacing: 12) {
            Text(egg.emoji)
                .font(.system(size: 56))
            Text("✅ 完成！可以关火了")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
            Button {
                highlightEgg(egg)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("再煮一次")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.15)))
            }
        }
    }

    private func idleSelectedView(egg: Egg) -> some View {
        VStack(spacing: 14) {
            Text(egg.emoji)
                .font(.system(size: 50))
            Text(egg.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
            Text("约 \(egg.durationSeconds / 60) 分钟")
                .font(.system(size: 13))
                .foregroundStyle(.black.opacity(0.5))
            Button {
                HapticsManager.lightTap()
                selectEgg(egg)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("开始煮")
                }
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange))
                .shadow(color: .orange.opacity(0.3), radius: 8, y: 4)
            }
        }
    }

    private var emptySelectionView: some View {
        VStack(spacing: 14) {
            Text("🍳")
                .font(.system(size: 60))
                .opacity(0.6)
            Text("选择一颗蛋开始煮蛋")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.black.opacity(0.4))
        }
    }

    // MARK: - Hint Text
    private var hintText: String {
        switch timerState {
        case .running:
            if let egg = selectedEgg, Double(elapsed) >= Double(egg.durationSeconds) * 0.9 {
                return "🔥 关火关火，就快煮好了！"
            }
            return "🔥 正在煮 \(selectedEgg?.name ?? "")"
        case .paused:
            return isUserPaused ? "⏸ 已暂停" : "🔥 后台运行中 · \(selectedEgg?.name ?? "")"
        case .done:
            return "✅ 完成！可以关火了"
        case .idle:
            return ""
        }
    }

    // MARK: - Siri Intent Listener
    private func setupIntentListener() {
        NotificationCenter.default.addObserver(
            forName: .startEggTimer,
            object: nil,
            queue: .main
        ) { notification in
            guard let eggName = notification.userInfo?["eggName"] as? String else { return }
            let allEggs = Egg.builtIn + Egg.customEggs
            if let egg = allEggs.first(where: { $0.name == eggName }) {
                self.selectEgg(egg)
            }
        }
    }

    // MARK: - Actions
    /// 选中蛋（高亮），不立即开始计时 → 用户需要点"开始煮"按钮确认
    private func highlightEgg(_ egg: Egg) {
        guard timerState != .running, timerState != .paused else { return }
        if selectedEgg?.id != egg.id { resetTimer() }
        selectedEgg = egg
        timerState = .idle
    }

    private func selectEgg(_ egg: Egg) {
        NotificationManager.cancelAll()
        timerCancellable?.cancel()
        timerCancellable = nil
        elapsed = 0
        pausedElapsed = 0
        timerState = .idle
        isUserPaused = false
        selectedEgg = egg

        LiveActivityManager.shared.startActivity(
            eggName: egg.name,
            eggEmoji: egg.emoji,
            total: egg.durationSeconds
        )

        startTimer()
    }

    private func pauseTimer() {
        if timerState == .running {
            timerCancellable?.cancel()
            timerCancellable = nil
            // 暂停时记录当前已累计时间
            pausedElapsed = computeElapsed()
            timerState = .paused
            isUserPaused = true
            if let egg = selectedEgg {
                LiveActivityManager.shared.pauseActivity(
                    eggName: egg.name,
                    elapsed: pausedElapsed,
                    total: egg.durationSeconds
                )
            }
        } else if timerState == .paused {
            // 恢复运行时直接复用 startTimer，复用同一 Timer
            startTimer()
        }
    }

    private func stopTimer() {
        NotificationManager.cancelAll()
        timerCancellable?.cancel()
        timerCancellable = nil
        // 只在计时自然完成时记录统计，手动停止不记录
        Egg.clearTimerPersistentState()
        Egg.resetWarningFlag()  // 清理预警标记
        LiveActivityManager.shared.endActivity()
        elapsed = 0
        pausedElapsed = 0
        timerStartTime = nil
        timerState = .idle
        isUserPaused = false
        selectedEgg = nil
    }

    private func startTimer() {
        let isResume = (timerState == .paused)
        // 新计时开始时重置预警标记；恢复运行时若已发过预警则保留标记（避免重复发）
        if !isResume && !Egg.hasSentWarning { Egg.resetWarningFlag() }
        // 恢复时 timerStartTime 设为 nil，下次 computeElapsed 会只返回 pausedElapsed
        timerStartTime = Date()
        timerState = .running

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [self] _ in
                guard let egg = selectedEgg else { return }
                let currentElapsed = computeElapsed()
                if currentElapsed < egg.durationSeconds {
                    elapsed = currentElapsed
                    let total = egg.durationSeconds
                    if total > 0, Double(currentElapsed) >= Double(total) * 0.9,
                       !Egg.hasSentWarning, UIApplication.shared.applicationState != .active {
                        AudioServicesPlaySystemSound(1007)
                        HapticsManager.warning()
                        NotificationManager.sendWarningNotification(eggName: egg.name)
                        Egg.hasSentWarning = true
                    }
                    // 每秒推送最新状态（elapsed/progress）给 Widget，驱动右侧数据实时刷新
                    let remaining = max(0, egg.durationSeconds - currentElapsed)
                    LiveActivityManager.shared.updateActivity(
                        elapsed: currentElapsed,
                        total: egg.durationSeconds,
                        hintText: "🔥 正在煮 \(egg.name)",
                        timerState: "running",
                        endTimeOverride: Date().addingTimeInterval(TimeInterval(remaining))
                    )
                } else {
                    // 计时完成
                    elapsed = currentElapsed
                    timerState = .done
                    timerCancellable?.cancel()
                    timerCancellable = nil
                    if UIApplication.shared.applicationState != .active {
                        NotificationManager.sendDoneNotification(eggName: egg.name)
                    }
                    AudioServicesPlaySystemSound(1005)
                    HapticsManager.success()
                    Egg.recordBoiling(seconds: currentElapsed)
                    Egg.clearTimerPersistentState()
                    Egg.resetWarningFlag()
                    LiveActivityManager.shared.endActivity(waitForDismiss: false)
                }
            }
        // 从暂停恢复时，通知 Live Activity 更新为 running
        if isResume, let egg = selectedEgg {
            LiveActivityManager.shared.resumeActivity(
                eggName: egg.name,
                eggEmoji: egg.emoji,
                elapsed: pausedElapsed,
                total: egg.durationSeconds
            )
        }
    }

    // MARK: - 后台计时修复：核心计算函数
    /// 计算当前已流逝的秒数（暂停期间也正确）
    private func computeElapsed() -> Int {
        guard selectedEgg != nil else { return 0 }
        if timerState == .paused {
            return pausedElapsed
        }
        // running 状态：pausedElapsed + 本轮经过的秒数
        guard let start = timerStartTime else { return pausedElapsed }
        let elapsedSinceStart = Int(Date().timeIntervalSince(start))
        return pausedElapsed + elapsedSinceStart
    }

    /// 进入后台前：保存当前已用时间（保持 timerState=running 让 Widget 显示正确状态）
    private func saveTimerState() {
        print("[EggClock] 🔴 saveTimerState called — timerState=\(timerState)")
        guard timerState == .running, let egg = selectedEgg else {
            print("[EggClock] 🔴 saveTimerState early return — not running or no egg")
            return
        }
        // 停止前台 Timer（节省资源）
        timerCancellable?.cancel()
        timerCancellable = nil

        // 记录当前已用时间
        pausedElapsed = computeElapsed()
        timerStartTime = nil
        isUserPaused = false  // false = App后台挂起（非用户手动暂停）

        // 退后台前推送最终状态（elapsed/endTime），确保 Widget 显示最新进度
        let currentEndTime = Date().addingTimeInterval(TimeInterval(egg.durationSeconds - pausedElapsed))
        LiveActivityManager.shared.updateActivity(
            elapsed: pausedElapsed,
            total: egg.durationSeconds,
            hintText: "🔥 \(egg.name) 后台运行中",
            timerState: "running",
            endTimeOverride: currentEndTime
        )
        print("[EggClock] 🔴 saveTimerState — elapsed=\(pausedElapsed) endTime=\(currentEndTime)")
        // endTime 是绝对时间戳，不会因 App 挂起而失效
        // 唯一需要保留 endTime 的原因是：持久化保存供冷启动恢复使用
        print("[EggClock] 🔴 saveTimerState — elapsed=\(pausedElapsed) endTime=\(currentEndTime) (no updateActivity)")

        // 持久化保存（App 被终止后冷启动也能恢复）
        Egg.saveTimerPersistentState(
            endTime: currentEndTime,
            pausedElapsed: pausedElapsed,
            egg: egg
        )

        // 如果进后台时已经超过 90%，补发预警通知（去重）
        if egg.durationSeconds > 0, Double(pausedElapsed) >= Double(egg.durationSeconds) * 0.9,
           !Egg.hasSentWarning {
            AudioServicesPlaySystemSound(1007)
            HapticsManager.warning()
            NotificationManager.sendWarningNotification(eggName: egg.name)
            Egg.hasSentWarning = true
        }

        // ── 后台保活（不再更新灵动岛，只为延长 App 后台时间以处理潜在通知）───
        _ = UIApplication.shared.beginBackgroundTask { }
    }

    /// App 恢复时：根据 Date 恢复计时（后台经过时间自动计入）
    private func restoreTimerIfNeeded() {
        print("[EggClock] 🟢 restoreTimerIfNeeded called — timerState=\(timerState) selectedEgg=\(selectedEgg?.name ?? "nil")")

        // 检测条件：timerState == .running 但 Timer 已被取消（说明是后台挂起回来的）
        // 或者 timerState == .paused（用户手动暂停后回到前台）
        let isBackgroundSuspended = (timerState == .running && timerCancellable == nil)
        guard (isBackgroundSuspended || timerState == .paused), let egg = selectedEgg else {
            print("[EggClock] 🟢 restoreTimerIfNeeded early return — state=\(timerState) hasTimer=\(timerCancellable != nil) egg=\(selectedEgg?.name ?? "nil")")
            return
        }

        // 防抖：2 秒内不重复恢复
        let now = Date()
        if let last = lastRestoreTime, now.timeIntervalSince(last) < 2.0 {
            print("[EggClock] 🟢 restoreTimerIfNeeded debounced — last restore \(Int(now.timeIntervalSince(last)))s ago")
            return
        }
        lastRestoreTime = now

        // 从持久化状态读取保存的 endTime，计算实际经过时间
        if let saved = Egg.loadTimerPersistentState() {
            // 正确公式：remaining = endTime 距现在还有多少秒
            let remaining = max(0, Int(saved.endTime.timeIntervalSince(now)))
            // actualElapsed = 保存时已走的 + 后台期间走过的
            let backgroundElapsed = (saved.total - saved.pausedElapsed) - remaining
            let actualElapsed = saved.pausedElapsed + max(0, backgroundElapsed)
            pausedElapsed = min(egg.durationSeconds, max(0, actualElapsed))
            print("[EggClock] 🟢 restoreTimerIfNeeded — actualElapsed=\(pausedElapsed) (was \(saved.pausedElapsed)) remaining=\(remaining)s")
        }

        // 恢复 LiveActivity 的 endTime（基于当前时间重新计算）
        let remaining = egg.durationSeconds - pausedElapsed
        let newEndTime = now.addingTimeInterval(TimeInterval(max(0, remaining)))
        LiveActivityManager.shared.updateActivity(
            elapsed: pausedElapsed,
            total: egg.durationSeconds,
            hintText: isUserPaused ? "⏸ 已暂停" : "🔥 继续煮 \(egg.name)",
            timerState: isUserPaused ? "paused" : "running",
            endTimeOverride: newEndTime
        )

        // 只有没有被用户手动暂停时才重启 Timer
        if !isUserPaused {
            timerStartTime = now
            startTimer()
        }
        print("[EggClock] 🟢 restoreTimerIfNeeded done")
    }

    private func resetTimer() {
        NotificationManager.cancelAll()
        timerCancellable?.cancel()
        timerCancellable = nil
        elapsed = 0
        pausedElapsed = 0
        timerStartTime = nil
        timerState = .idle
        isUserPaused = false
        selectedEgg = nil
        LiveActivityManager.shared.endActivity()
    }

    private func deleteCustomEgg(_ egg: Egg) {
        Egg.removeCustom(id: egg.id)
        customEggs = Egg.customEggs
        if selectedEgg?.id == egg.id { resetTimer() }
    }
}

// MARK: - Egg Row Button
struct EggRowButton: View {
    let egg: Egg
    let isActive: Bool
    let isDone: Bool
    let isCustom: Bool
    let onTap: () -> Void
    var onEdit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    Text(egg.emoji).font(.system(size: 26))
                    Text(egg.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(.black)
                    Spacer()
                    if isCustom {
                        Image(systemName: "person.fill.badge.plus")
                            .font(.system(size: 13)).foregroundStyle(.orange.opacity(0.6))
                    }
                    if isActive {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 18)).foregroundStyle(.orange)
                    } else if isDone {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20)).foregroundStyle(.green)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(isActive ? Color.orange.opacity(0.18) : Color(red: 1.0, green: 0.97, blue: 0.88))
                .clipShape(.rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(isActive ? 0.7 : 0), lineWidth: 1.5))
            }
            .buttonStyle(.plain)

            if isCustom, let onEdit = onEdit {
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.orange.opacity(0.55))
                }
                .padding(.leading, 8)
            }
        }
    }
}

// MARK: - 统计页面
struct StatsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 累计统计卡片
                    HStack(spacing: 0) {
                        statCard(
                            title: "煮蛋次数",
                            value: "\(Egg.totalCount)",
                            unit: "次",
                            color: .orange
                        )
                        Divider().frame(height: 60)
                        statCard(
                            title: "累计时长",
                            value: Egg.formattedTotalTime,
                            unit: "",
                            color: .orange
                        )
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(red: 1.0, green: 0.97, blue: 0.88))
                    )
                    .padding(.horizontal, 20)

                    // 蛋种列表（带时长对比条）
                    VStack(alignment: .leading, spacing: 14) {
                        Text("蛋种")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        let allEggs = Egg.allEggs
                        let maxDuration = allEggs.map(\.durationSeconds).max() ?? 1

                        ForEach(allEggs, id: \.id) { egg in
                            HStack(spacing: 10) {
                                Text(egg.emoji).font(.system(size: 22))
                                Text(egg.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.black)
                                    .frame(width: 70, alignment: .leading)

                                // 时长对比条
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(.black.opacity(0.06))
                                        Capsule().fill(
                                            Color.orange.opacity(0.6)
                                        )
                                        .frame(width: geo.size.width * CGFloat(egg.durationSeconds) / CGFloat(maxDuration))
                                    }
                                }
                                .frame(height: 8)

                                Text("\(egg.durationSeconds / 60) min")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 42, alignment: .trailing)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground).opacity(0.5))
                    )
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 8)
            }
            .background(Color(red: 1.0, green: 0.84, blue: 0.0).ignoresSafeArea())
            .navigationTitle("📊 煮蛋统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func statCard(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 6) {
            if unit.isEmpty {
                Text(value)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    Text(unit)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - TimerState
enum TimerState {
    case idle, running, paused, done
}

#Preview { ContentView() }