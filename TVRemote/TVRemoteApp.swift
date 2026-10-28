import SwiftUI

@main
struct TVRemoteApp: App {
    @State private var model = RemoteModel()
    @State private var discovery = Discovery()

    var body: some Scene {
        WindowGroup("TV Remote") {
            ContentView(model: model, discovery: discovery)
                .task { discovery.start() }
        }
        .windowResizability(.contentSize)
    }
}
