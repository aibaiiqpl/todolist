import SwiftUI

@main
struct TodoListApp: App {
    @StateObject private var store = TodoStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onOpenURL { _ in }
        }
    }
}
