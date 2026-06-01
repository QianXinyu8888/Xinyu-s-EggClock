//
//  ContentView.swift
//  EggClock
//
//  主界面
//

import SwiftUI
import Combine

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
                    onTap: { selectEgg(egg) }
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
                        onTap: { selectEgg(egg) }
                    )
                    .contextMenu {
                        Button {
                            editingEgg = egg
                            showEditor = true
                        } label: {
                            Label("编辑", systemImage: "pencil")
                        }
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
            // 暂停 / 终止 大图标按钮（计时中出现）
            if timerState == .running || timerState == .paused {
                HStack(spacing: 32) {
                    Button {
                        pauseTimer()
                    } label: {
                        Image(systemName: timerState == .paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 80, height: 80)
                            .background(Circle().fill(Color(red: 1.0, green: 0.97, blue: 0.88)))
                            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    }

                    Button {
                        stopTimer()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 80, height: 80)
                            .background(Circle().fill(Color.red.opacity(0.8)))
                            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }

            // 核心计时区
            VStack(spacing: 10) {
                Text(selectedEgg?.emoji ?? "🍳")
                    .font(.system(size: 72))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

                Text(timerState == .idle ? "0/\(selectedEgg?.durationSeconds ?? 0)s" : "\(elapsed)/\(selectedEgg?.durationSeconds ?? 0)s")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 1.0, green: 0.97, blue: 0.88)))
                    .contentTransition(.numericText())

                Text(hintText)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 1.0, green: 0.97, blue: 0.88)))
            }

        }
        .padding(.bottom, 60)
    }

    // MARK: - Hint Text
    private var hintText: String {
        switch timerState {
        case .idle:
            return selectedEgg == nil ? "👆 请选择一个蛋" : "🔥 煮 \(selectedEgg!.name) · \(selectedEgg!.durationSeconds / 60) 分钟"
        case .running:
            if let egg = selectedEgg, elapsed >= egg.warningSeconds {
                return "🔥 关火关火，就快煮好了！"
            }
            return "🔥 正在煮 \(selectedEgg?.name ?? "")"
        case .paused:
            return "⏸ 已暂停"
        case .done:
            return "✅ 完成！可以关火了"
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
    private func selectEgg(_ egg: Egg) {
        NotificationManager.cancelAll()
        timerCancellable?.cancel()
        timerCancellable = nil
        elapsed = 0
        timerState = .idle
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
            timerState = .paused
            if let egg = selectedEgg {
                LiveActivityManager.shared.pauseActivity(
                    eggName: egg.name,
                    elapsed: elapsed,
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
        if elapsed > 0 {
            Egg.recordBoiling(seconds: elapsed)
        }
        LiveActivityManager.shared.endActivity()
        elapsed = 0
        timerState = .idle
        selectedEgg = nil
    }

    private func startTimer() {
        let isResume = (timerState == .paused)
        timerState = .running
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [self] _ in
                guard let egg = selectedEgg else { return }
                if elapsed < egg.durationSeconds {
                    elapsed += 1
                    if elapsed == egg.warningSeconds {
                        NotificationManager.sendWarningNotification(eggName: egg.name)
                    }
                    LiveActivityManager.shared.updateActivity(
                        elapsed: elapsed,
                        total: egg.durationSeconds,
                        hintText: hintText,
                        timerState: "running"
                    )
                } else {
                    timerState = .done
                    timerCancellable?.cancel()
                    timerCancellable = nil
                    NotificationManager.sendDoneNotification(eggName: egg.name)
                    Egg.recordBoiling(seconds: elapsed)
                    LiveActivityManager.shared.endActivity(waitForDismiss: false)
                }
            }
        // 从暂停恢复时，通知 Live Activity 更新为 running
        if isResume, let egg = selectedEgg {
            LiveActivityManager.shared.resumeActivity(
                eggName: egg.name,
                eggEmoji: egg.emoji,
                elapsed: elapsed,
                total: egg.durationSeconds
            )
        }
    }

    private func resetTimer() {
        NotificationManager.cancelAll()
        timerCancellable?.cancel()
        timerCancellable = nil
        elapsed = 0
        timerState = .idle
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

    var body: some View {
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
                        .symbolEffect(.bounce, options: .repeating)
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
    }
}

// MARK: - 统计页面
struct StatsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack {
                            Text("\(Egg.totalCount)")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                            Text("次").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)

                        Divider()

                        VStack {
                            Text(Egg.formattedTotalTime)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                            Text("总时长").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("累计煮蛋统计")
                }

                Section {
                    ForEach(Egg.builtIn) { egg in
                        HStack {
                            Text(egg.emoji)
                            Text(egg.name)
                            Spacer()
                            Text("\(egg.durationSeconds / 60) 分钟")
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(Egg.customEggs) { egg in
                        HStack {
                            Text(egg.emoji)
                            Text(egg.name)
                            Spacer()
                            Text("\(egg.durationSeconds / 60) 分钟")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("所有蛋种")
                }
            }
            .navigationTitle("📊 煮蛋统计")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - TimerState
enum TimerState {
    case idle, running, paused, done
}

#Preview { ContentView() }