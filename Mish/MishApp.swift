import SwiftUI
import UIKit

@main
struct MishApp: App {
    @StateObject private var player = PlayerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .preferredColorScheme(.dark)
        }
    }
    init() {
    for family in UIFont.familyNames.sorted() {
        for name in UIFont.fontNames(forFamilyName: family) {
            if name.localizedCaseInsensitiveContains("Dela") {
                print("FOUND FONT:", name)
            }
        }
    }
}
}
