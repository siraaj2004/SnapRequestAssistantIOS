import SwiftUI

@main
struct SnapRequestAssistantApp: App {
    @StateObject private var store = SnapRequestStore()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
