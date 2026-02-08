//
//  rps_robot_handApp.swift
//  rps-robot-hand
//
//  Created by Phu Nguyen on 6/6/25.
//

import SwiftUI
import SwiftData
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .all

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .landscape
        }
        return AppDelegate.orientationLock
    }
}

@main
struct rps_robot_handApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: [RobotProgram.self, ProgramCommand.self])
    }
}
