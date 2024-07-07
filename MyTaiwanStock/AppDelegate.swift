//
//  AppDelegate.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/3.
//

import UIKit
import Firebase
import FirebaseMessaging
import GoogleSignIn
import os

let logger = Logger(subsystem: "com.a2006mike.MyTaiwanStock", category: "YourCategory")

@main
class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate {
    var deviceId: String?
    var networkService:NetworkServiceImpl?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        FirebaseApp.configure()
        registerForPushNotifications()
        Messaging.messaging().delegate = self
        // 取得或生成裝置ID
        if let existingDeviceId = UserDefaults.standard.string(forKey: "deviceId") {
            deviceId = existingDeviceId
        } else {
            let newDeviceId = UUID().uuidString
            UserDefaults.standard.set(newDeviceId, forKey: "deviceId")
            deviceId = newDeviceId
        }
        
        print("Device ID: \(deviceId ?? "unknown")")
        return true
    }
    func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            print("Permission granted: \(granted)")
            guard granted else { return }
            self.getNotificationSettings()
        }
    }
    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    // Firebase Messaging
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        messaging.token { fcmToken, error in
            guard let token=fcmToken else {return}
            if let error=error{
                print("fcm error: \(error)")
            }
            self.networkService = NetworkServiceImpl()
            if let deviceId = self.deviceId {
                self.networkService?.sendDeviceIdToServer(deviceId: deviceId, token: token)
                print("fcm token \(token)")
            }
        }
    }

    
    // Apple Messaging
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data -> String in
            return String(format: "%02.2hhx", data)
        }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register: \(error)")
    }
    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    @available(iOS 9.0, *)
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any])
      -> Bool {
      return GIDSignIn.sharedInstance.handle(url)
    }
}


