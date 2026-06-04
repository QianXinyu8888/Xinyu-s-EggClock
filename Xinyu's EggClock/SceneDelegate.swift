//
//  SceneDelegate.swift
//  Xinyu's App2
//
//  SwiftUI 入口
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = UIHostingController(rootView: ContentView())
        window?.makeKeyAndVisible()

        // 注册 Siri Shortcuts 通知监听器（支持冷启动）
        registerSiriIntentListener()
    }

    // MARK: - Siri Shortcut 冷启动支持
    private func registerSiriIntentListener() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("startEggTimer"),
            object: nil,
            queue: .main
        ) { notification in
            guard let eggName = notification.userInfo?["eggName"] as? String else { return }
            Task { @MainActor in
                TimerCoordinator.shared.setPendingEgg(eggName)
            }
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        print("🔗 收到 URL: \(url)")
    }
}
