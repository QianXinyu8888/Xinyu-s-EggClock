//
//  EggEditorView.swift
//  EggClock
//
//  添加/编辑自定义食材 Sheet
//

import SwiftUI

struct EggEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let existingEgg: Egg?
    let onSave: (Egg) -> Void
    let onDelete: ((Egg) -> Void)?

    @State private var name: String = ""
    @State private var emoji: String = ""
    @State private var minutes: Int = 5

    private let quickEmojis = ["🥚", "🍳", "🐣", "🐔", "🍗", "🥩", "🥓", "🌽", "🍠", "🥦", "🥕", "🍆", "🍱", "🥪", "🥗", "🍜"]

    var body: some View {
        NavigationStack {
            Form {
                Section("图标") {
                    HStack(spacing: 16) {
                        // Emoji 预览 & 输入框
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.systemGray6))
                                .frame(width: 72, height: 72)

                            if emoji.isEmpty {
                                Text("🍳")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(emoji)
                                    .font(.system(size: 42))
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            TextField("从键盘输入你的自定义emoji", text: $emoji)
                                .font(.system(size: 18))
                                .textFieldStyle(.roundedBorder)
                                .frame(height: 36)
                                .onChange(of: emoji) { _, newValue in
                                    // 只保留最后一个字符（防止粘贴多个）
                                    if newValue.count > 1 {
                                        emoji = String(newValue.suffix(1))
                                    }
                                }

                            Text("从下方快速选择")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    // 快速选择网格
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 6) {
                        ForEach(quickEmojis, id: \.self) { e in
                            Text(e)
                                .font(.system(size: 26))
                                .frame(width: 38, height: 38)
                                .background(
                                    Circle()
                                        .fill(emoji == e ? Color.orange.opacity(0.25) : Color.clear)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(emoji == e ? Color.orange : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture { emoji = e }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("名称") {
                    TextField("例如：溏心蛋", text: $name)
                }

                Section("计时时长") {
                    Stepper("共 \(minutes) 分钟", value: $minutes, in: 1...60)
                }

                if existingEgg != nil {
                    Section {
                        Button("删除这个食材", role: .destructive) {
                            if let egg = existingEgg { onDelete?(egg) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(existingEgg == nil ? "添加食材" : "编辑食材")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || emoji.isEmpty)
                }
            }
            .onAppear {
                if let egg = existingEgg {
                    name = egg.name
                    emoji = egg.emoji
                    minutes = egg.durationSeconds / 60
                }
            }
        }
    }

    private func save() {
        let egg = Egg(
            id: existingEgg?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            emoji: emoji,
            durationSeconds: minutes * 60,
            warningSeconds: (minutes * 60 * 9) / 10  // 始终为总时长的 90%
        )
        onSave(egg)
        dismiss()
    }
}