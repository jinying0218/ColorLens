import SwiftUI
import ColorCore

@MainActor
final class ColorStore: ObservableObject {
    @Published private(set) var library: ColorLibrary
    private let defaults: UserDefaults
    private let key = "ColorLens.savedColors.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        library = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(ColorLibrary.self, from: $0) } ?? ColorLibrary()
    }

    func record(_ color: ColorValue) { library.record(color); save() }
    func toggleFavorite(_ color: ColorValue) { library.toggleFavorite(color); save() }
    func clearRecent() { library.clearRecent(); save() }
    private func save() {
        if let data = try? JSONEncoder().encode(library) { defaults.set(data, forKey: key) }
    }
}

struct ColorLibraryView: View {
    @ObservedObject var store: ColorStore
    let current: ColorValue
    let valid: Bool
    let restore: (ColorValue) -> Void
    let clear: () -> Void
    @State private var favoritesOnly = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("我的颜色").font(.title2.bold())
            Button {
                store.toggleFavorite(current)
            } label: {
                Label(store.library.favorites.contains(current) ? "取消收藏当前颜色" : "收藏当前颜色",
                      systemImage: store.library.favorites.contains(current) ? "star.fill" : "star")
            }.disabled(!valid)
            Picker("颜色列表", selection: $favoritesOnly) {
                Text("历史 \(store.library.recent.count)").tag(false)
                Text("收藏 \(store.library.favorites.count)").tag(true)
            }.pickerStyle(.segmented)
            if !favoritesOnly {
                HStack {
                    Text("最近使用 · 最多 100 条").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("清空") { clear() }
                        .disabled(store.library.recent.isEmpty)
                        .help("清空颜色历史，保留收藏")
                }
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    let colors = favoritesOnly ? store.library.favorites : store.library.recent
                    if colors.isEmpty {
                        Text(favoritesOnly ? "点星标，留下常用颜色" : "输入、取色或复制后自动记录")
                            .font(.caption).foregroundStyle(.secondary).padding(.top, 24)
                    }
                    ForEach(colors, id: \.self) { color in
                        HStack(spacing: 8) {
                            Button { restore(color) } label: {
                                HStack(spacing: 8) {
                                    ZStack {
                                        Checkerboard()
                                        Color(.sRGB, red: Double(color.red)/255, green: Double(color.green)/255,
                                              blue: Double(color.blue)/255, opacity: Double(color.alpha)/255)
                                    }.frame(width: 32, height: 32).clipShape(RoundedRectangle(cornerRadius: 6))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(color.hex(.argb)).font(.system(size: 11, design: .monospaced))
                                        Text(String(format: "透明度 %.0f%%", Double(color.alpha)/255*100))
                                            .font(.system(size: 10)).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain).help("恢复此颜色")
                            Button { store.toggleFavorite(color) } label: {
                                Image(systemName: store.library.favorites.contains(color) ? "star.fill" : "star")
                                    .foregroundStyle(store.library.favorites.contains(color) ? Color.orange : Color.secondary)
                            }.buttonStyle(.plain).help("收藏或取消收藏")
                        }
                        .padding(8)
                        .background(current == color ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            Text("只保存在这台 Mac，不联网同步。")
                .font(.caption2).foregroundStyle(.secondary)
        }.padding(18)
    }
}
