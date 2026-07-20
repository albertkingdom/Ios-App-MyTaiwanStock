//
//  SceneDelegate.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/3.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private func setInitialViewController(in window: UIWindow) {
        // 主畫面
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        guard
            let tabBarController = storyboard.instantiateViewController(
                withIdentifier: "customTabVC") as? CustomTabBarViewController
        else {
            fatalError(
                "Could not find CustomTabBarViewController in storyboard")
        }

        let stockListNavController = UINavigationController()
        stockListNavController.tabBarItem = UITabBarItem(
            title: "列表",
            image: UIImage(systemName: "chart.line.uptrend.xyaxis")?
                .withRenderingMode(.alwaysOriginal),
            selectedImage: UIImage(
                systemName: "chart.line.uptrend.xyaxis.fill")?
                .withRenderingMode(.alwaysTemplate)
        )
        setupNavigationBarAppearance()
        if let viewControllers = tabBarController.viewControllers {
            var mutableViewControllers = viewControllers
            mutableViewControllers[0] = stockListNavController  // 假设第一个标签是股票列表
            tabBarController.viewControllers = mutableViewControllers
        } else {
            tabBarController.viewControllers = [stockListNavController]
        }
        let appCoordinator = AppCoordinator(
            navigationController: stockListNavController)
        window.rootViewController = tabBarController
        appCoordinator.start()

    }
    func scene(
        _ scene: UIScene, willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)

        self.window = window

        setInitialViewController(in: window)
        window.makeKeyAndVisible()

        //let masterTabBarController = window?.rootViewController as! UITabBarController
        //let topNavController = masterTabBarController.viewControllers?.first as! UINavigationController

        //let listController = topNavController.topViewController as! StockListViewController
        //let statisticController = masterTabBarController.viewControllers?[1] as! StatisticViewController

    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.

    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }

}

extension SceneDelegate {
    private func setupNavigationBarAppearance() {
        // iOS 15及以上的設置方式
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()

            // 設置導航欄標題顏色
            appearance.titleTextAttributes = [
                .foregroundColor: UIColor.label
            ]

            // 設置大標題顏色
            appearance.largeTitleTextAttributes = [
                .foregroundColor: UIColor.label
            ]

            // 設置背景顏色
            appearance.backgroundColor = .systemBackground

            // 應用到所有導航欄
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance

            // 設置返回按鈕顏色（全局）
            UINavigationBar.appearance().tintColor = .systemGray
        } else {
            // iOS 15以下的設置方式
            UINavigationBar.appearance().barTintColor = .systemBackground
            UINavigationBar.appearance().tintColor = .systemGray
            UINavigationBar.appearance().titleTextAttributes = [
                .foregroundColor: UIColor.label
            ]
        }

    }

}
