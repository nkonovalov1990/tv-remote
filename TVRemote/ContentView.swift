import SwiftUI

struct ContentView: View {
    @Bindable var model: RemoteModel
    var discovery: Discovery
    private enum Field { case host, pad }
    @FocusState private var focus: Field?

    var body: some View {
        VStack(spacing: 12) {
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
            }
            Text(model.status)
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                btn(.power, "power", "Питание").buttonStyle(.borderedProminent).tint(.red)
                btn(.home, "house", "Домой")
                btn(.back, "arrow.uturn.backward", "Назад")
            }
            HStack {
                btn(.input, "rectangle.on.rectangle", "Источник сигнала")
                btn(.settings, "gearshape", "Настройки")
            }
            Grid {
                GridRow { Color.clear.gridCellUnsizedAxes(.vertical); btn(.up, "chevron.up", "Вверх"); Color.clear.gridCellUnsizedAxes(.vertical) }
                GridRow {
                    btn(.left, "chevron.left", "Влево")
                    btn(.ok, "circle.fill", "OK")
                    btn(.right, "chevron.right", "Вправо")
                }
                GridRow { Color.clear.gridCellUnsizedAxes(.vertical); btn(.down, "chevron.down", "Вниз"); Color.clear.gridCellUnsizedAxes(.vertical) }
            }
            HStack {
                btn(.volumeDown, "speaker.minus", "Громкость меньше")
                btn(.mute, "speaker.slash", "Без звука")
                btn(.volumeUp, "speaker.plus", "Громкость больше")
            }
            HStack {
                btn(.rewind, "backward", "Перемотка назад")
                btn(.playPause, "playpause", "Пауза / воспроизведение")
                btn(.fastForward, "forward", "Перемотка вперёд")
            }
        }
        .padding()
        .frame(width: 280)
        .focusable()
        .focused($focus, equals: .pad)
        .focusEffectDisabled()
        .onAppear { focus = .pad }
        .onKeyPress(phases: [.down, .repeat]) { p in // R5; ignored while typing the IP
            guard focus != .host, let key = shortcut(p.key) else { return .ignored }
            Task { await model.press(key) }
            return .handled
        }
    }

    private func shortcut(_ k: KeyEquivalent) -> Key? {
        switch k {
        case .upArrow: .up
        case .downArrow: .down
        case .leftArrow: .left
        case .rightArrow: .right
        case .return: .ok
        case .escape, .delete: .back
        default: nil
        }
    }

    private func btn(_ key: Key, _ symbol: String, _ label: String) -> some View {
        Button { Task { await model.press(key) } } label: {
            Image(systemName: symbol).frame(maxWidth: .infinity, minHeight: 24)
        }
        .help(label)
        .accessibilityLabel(label)
    }
}
