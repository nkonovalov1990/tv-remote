import SwiftUI

/// One trapezoid of the D-pad; `quarter` = clockwise 90° turns from "up".
struct Sector: Shape {
    /// OK takes 25% of the D-pad area (half the side), so sectors are this deep.
    static let depth = 0.25
    var quarter: Int
    func path(in r: CGRect) -> Path {
        var p = Path()
        // Exact diagonals: neighbours share an edge, so their 1pt strokes merge into an even hairline.
        let pts = [(0.0, 0.0), (1.0, 0.0), (1 - Self.depth, Self.depth), (Self.depth, Self.depth)].map { pt -> CGPoint in
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
                if model.status == RemoteModel.localNetworkHint { // R19
                    Button("Открыть настройки") { NSWorkspace.shared.open(RemoteModel.localNetworkSettings) }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            // Own segmented control: the system one can't be made 32pt tall.
            HStack(spacing: 2) {
                ForEach([(Tab.media, "Медиа"), (.nav, "Навигация")], id: \.0) { tab, title in
                    let on = model.tab == tab
                    Button { model.tab = tab } label: {
                        Text(title).font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(on ? surface : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(on ? 0.15 : 0), radius: 1, y: 1)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(2)
            .frame(height: 32)
            .background(Color(nsColor: .separatorColor), in: RoundedRectangle(cornerRadius: 10))

            Group {
                switch model.tab {
                case .media: media
                case .nav: nav
                }
            }
            .frame(height: side)

            Divider()
            HStack(spacing: 8) {
                key(.power, "power", "Питание", size: 16, tint: .red, shape: RoundedRectangle(cornerRadius: 10)).frame(height: 32)
                key(.home, "house", "Домой", size: 16, shape: RoundedRectangle(cornerRadius: 10)).frame(height: 32)
                key(.back, "arrow.uturn.backward", "Назад", size: 16, shape: RoundedRectangle(cornerRadius: 10)).frame(height: 32)
            }
        }
        .padding(16)
        .frame(width: 340)
        .focusable()
        .focused($focus, equals: .pad)
        .focusEffectDisabled()
        .onAppear { focus = .pad }
        .task { // R10 connect first, then R17 poll; cancelled when the popover closes
            await model.connectIfSaved()
            while !Task.isCancelled {
                await model.refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .onKeyPress(phases: [.down, .repeat]) { p in // R5'; ignored while typing the IP
            guard focus != .host, let key = shortcut(p.key) else { return .ignored }
            Task { await model.press(key) }
            return .handled
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            let asleep = model.isConnected && model.tv?.awake == false // R13
            Circle().fill(!model.isConnected ? Color.orange : asleep ? Color.secondary : Color.green).frame(width: 8, height: 8)
                .accessibilityLabel(!model.isConnected ? "Нет связи" : asleep ? "ТВ спит" : "ТВ включён")
            Text(model.tv?.appName ?? (model.host.isEmpty ? "Телевизор не выбран" : model.host)) // R14
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
        let tv = model.tv
        return VStack(spacing: 12) {
            Button { Task { await model.press(.playPause) } } label: {
                RoundedRectangle(cornerRadius: 20).fill(accent)
                    .overlay(VStack(spacing: 6) { // R16
                        Image(systemName: tv?.playing.map { $0 ? "pause.fill" : "play.fill" } ?? "playpause.fill").font(.system(size: 40))
                        if let t = tv?.title { Text(t).font(.system(size: 13)).lineLimit(1).truncationMode(.tail).padding(.horizontal, 16) }
                    }.foregroundStyle(.white))
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            }
            .buttonStyle(Press())
            .help("Пауза / воспроизведение (пробел)").accessibilityLabel("Пауза / воспроизведение")
            HStack(spacing: 0) {
                key(.volumeDown, "speaker.minus", "Громкость меньше", size: 40, shape: UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20), value: tv?.volume)
                key(.volumeUp, "speaker.plus", "Громкость больше", size: 40, shape: UnevenRoundedRectangle(bottomTrailingRadius: 20, topTrailingRadius: 20), value: tv?.volume)
            }
            .overlay { // R15: sits on the divider between − and +
                if let v = tv?.volume {
                    Text("\(v)").font(.system(size: 15, weight: .semibold)).foregroundStyle(.secondary)
                        .padding(.horizontal, 6).background(surface).allowsHitTesting(false)
                }
            }
        }
    }

    private var nav: some View {
        let edges: [(Key, String, String, Alignment)] = [
            (.up, "chevron.up", "Вверх", .top), (.right, "chevron.right", "Вправо", .trailing),
            (.down, "chevron.down", "Вниз", .bottom), (.left, "chevron.left", "Влево", .leading),
        ]
        return ZStack {
            surface
            ForEach(edges.indices, id: \.self) { i in
                key(edges[i].0, edges[i].1, edges[i].2, size: 28, shape: Sector(quarter: i), align: edges[i].3, inset: side * Sector.depth / 2 - 14) // centre the 28pt glyph in the sector's depth
            }
            Button { Task { await model.press(.ok) } } label: {
                Rectangle().fill(surface)
                    .overlay(Rectangle().stroke(Color(nsColor: .separatorColor)))
                    .overlay(Image(systemName: "circle").font(.system(size: 40)).foregroundStyle(.primary))
            }
            .buttonStyle(Press())
            .frame(width: side * (1 - 2 * Sector.depth), height: side * (1 - 2 * Sector.depth)) // flush with the sectors' inner edges
            .help("OK (Return)").accessibilityLabel("OK")
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(nsColor: .separatorColor)))
    }

    /// The repeated key look: surface fill + hairline border, icon aligned inside; only the shape is hit-testable.
    private func key<S: Shape>(_ k: Key, _ symbol: String, _ label: String, size: CGFloat = 22,
                               tint: Color = .primary, shape: S, align: Alignment = .center, inset: CGFloat = 0, value: Int? = nil) -> some View {
        Button { Task { await model.press(k) } } label: {
            shape.fill(surface)
                .overlay(shape.stroke(Color(nsColor: .separatorColor)))
                .overlay(Image(systemName: symbol).font(.system(size: size)).foregroundStyle(tint).padding(inset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: align))
                .contentShape(shape)
        }
        .buttonStyle(Press())
        .help(label).accessibilityLabel(label).accessibilityValue(value.map(String.init) ?? "")
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
