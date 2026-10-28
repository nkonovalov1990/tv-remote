import SwiftUI

@main
struct TVRemoteApp: App {
    @State private var model = RemoteModel()
    @State private var discovery: Discovery

    init() { // start here: the popover content may not exist until first opened
        let d = Discovery()
        d.start()
        _discovery = State(initialValue: d)
    }

    var body: some Scene {
        MenuBarExtra("TV Remote", systemImage: "tv") {
            ContentView(model: model, discovery: discovery)
        }
        .menuBarExtraStyle(.window)
    }
}
