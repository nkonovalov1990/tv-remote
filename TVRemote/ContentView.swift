import SwiftUI

/// One trapezoid of the D-pad (prototype v2 clip-paths); `quarter` = clockwise 90° turns from "up".
struct Sector: Shape {
    var quarter: Int
    func path(in r: CGRect) -> Path {
        var p = Path()
        let pts = [(0.01, 0.0), (0.99, 0.0), (0.787, 0.212), (0.213, 0.212)].map { pt -> CGPoint in
            var (x, y) = pt
            for _ in 0..<quarter { (x, y) = (1 - y, x) }
            return CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height)
        }
        p.addLines(pts)
        p.closeSubpath()
        return p
    }
}

private struct Press: ButtonStyle {
    func makeBody(configuration c: Configuration) -> some View {
        c.label.brightness(c.isPressed ? -0.1 : 0)
    }
}

struct ContentView: View {
    @Bindable var model: RemoteModel
    var discovery: Discovery
    private enum Field { case host, pad }
    @FocusState private var focus: Field?
    @State private var showSettings = false

    private let side: CGFloat = 308
    private let accent = Color(red: 0x0A / 255, green: 0x5F / 255, blue: 0xD6 / 255)
    private let surface = Color(nsColor: .controlBackgroundColor)

    var body: some View {
        VStack(spacing: 12) {
            header
            if showSettings || model.host.isEmpty { settings }
            if !model.isConnected {
                Text(model.status)
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Picker("Режим", selection: $model.tab) {
                Text("Медиа").tag(Tab.media)
                Text("Навигация").tag(Tab.nav)
            }
            .pickerStyle(.segmented).labelsHidden()

            Group {
                switch model.tab {
                case .media: media
                case .nav: nav
                }
            }
            .frame(height: side)

            Divider()
            HStack(spacing: 8) {
                key(.power, "power", "Питание", tint: .red, shape: RoundedRectangle(cornerRadius: 12))
                    .frame(height: 44)
                key(.home, "house", "Домой", shape: RoundedRectangle(cornerRadius: 12)).frame(height: 44)
                key(.back, "arrow.uturn.backward", "Назад", shape: RoundedRectangle(cornerRadius: 12)).frame(height: 44)
            }
        }
        .padding(16)
        .frame(width: 340)
        .focusable()
        .focused($focus, equals: .pad)
        .focusEffectDisabled()
        .onAppear { focus = .pad }
        .task { await model.connectIfSaved() } // R10
        .onKeyPress(phases: [.down, .repeat]) { p in // R5'; ignored while typing the IP
            guard focus != .host, let key = shortcut(p.key) else { return .ignored }
            Task { await model.press(key) }
            return .handled
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle().fill(model.isConnected ? Color.green : Color.orange).frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(model.host.isEmpty ? "Телевизор не выбран" : model.host)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button { showSettings.toggle() } label: { Image(systemName: "gearshape") }
                .buttonStyle(.borderless)
                .help("Настройки").accessibilityLabel("Настройки")
        }
    }

    private var settings: some View {
        VStack(spacing: 8) {
            TextField("IP телевизора", text: $model.host)
                .focused($focus, equals: .host)
                .onSubmit { focus = .pad }
                .textFieldStyle(.roundedBorder)
            HStack {
                Menu("Найденные ТВ") {
                    ForEach(discovery.tvs) { tv in Button(tv.name) { model.host = tv.host } }
                }
                .disabled(discovery.tvs.isEmpty)
                Button("Подключить") { Task { await model.connect() } }
                Spacer()
                Button("Выйти") { NSApp.terminate(nil) }
            }
        }
    }

    private var media: some View {
        VStack(spacing: 12) {
            Button { Task { await model.press(.playPause) } } label: {
                RoundedRectangle(cornerRadius: 20).fill(accent)
                    .overlay(Image(systemName: "playpause.fill").font(.system(size: 64)).foregroundStyle(.white))
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            }
            .buttonStyle(Press())
            .help("Пауза / воспроизведение (пробел)").accessibilityLabel("Пауза / воспроизведение")
            HStack(spacing: 0) {
                key(.volumeDown, "speaker.minus", "Громкость меньше", size: 40, shape: UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20))
                key(.volumeUp, "speaker.plus", "Громкость больше", size: 40, shape: UnevenRoundedRectangle(bottomTrailingRadius: 20, topTrailingRadius: 20))
            }
        }
    }

    private var nav: some View {
        let edges: [(Key, String, String, Alignment)] = [
            (.up, "chevron.up", "Вверх", .top), (.right, "chevron.right", "Вправо", .trailing),
            (.down, "chevron.down", "Вниз", .bottom), (.left, "chevron.left", "Влево", .leading),
        ]
        return ZStack {
            Color(nsColor: .separatorColor) // shows through the gaps between sectors
            ForEach(edges.indices, id: \.self) { i in
                key(edges[i].0, edges[i].1, edges[i].2, size: 28, shape: Sector(quarter: i), align: edges[i].3, inset: 8)
            }
            Button { Task { await model.press(.ok) } } label: {
                RoundedRectangle(cornerRadius: 20).fill(Color(nsColor: .windowBackgroundColor))
                    .overlay(Image(systemName: "circle").font(.system(size: 40)).foregroundStyle(.primary))
            }
            .buttonStyle(Press())
            .frame(width: side * 0.574, height: side * 0.574)
            .help("OK (Return)").accessibilityLabel("OK")
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    /// The repeated key look: surface fill + hairline border, icon aligned inside; only the shape is hit-testable.
    private func key<S: Shape>(_ k: Key, _ symbol: String, _ label: String, size: CGFloat = 22,
                               tint: Color = .primary, shape: S, align: Alignment = .center, inset: CGFloat = 0) -> some View {
        Button { Task { await model.press(k) } } label: {
            shape.fill(surface)
                .overlay(shape.stroke(Color(nsColor: .separatorColor)))
                .overlay(Image(systemName: symbol).font(.system(size: size)).foregroundStyle(tint).padding(inset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align))
                .contentShape(shape)
        }
        .buttonStyle(Press())
        .help(label).accessibilityLabel(label)
    }

    private func shortcut(_ k: KeyEquivalent) -> Key? {
        switch k {
        case .upArrow: .up
        case .downArrow: .down
        case .leftArrow: .left
        case .rightArrow: .right
        case .return: .ok
        case .escape, .delete: .back
        case .space: .playPause
        default: nil
        }
    }
}
