import Cocoa
import SwiftUI

final class Controller: ObservableObject {
    enum Mode: String { case system = "系统自动", steady = "常亮", breathe = "呼吸", off = "关闭" }
    @Published var mode = Mode.system
    @Published var level = 50.0
    @Published var message = ""
    let lamp = Lamp()
    let curve = "LEPWMBrightnessNitsMapping"
    let minimum = "LEPWMLuxToMinNitsRestrictionMapping"
    let maximum = "LEPWMLuxToMaxNitsRestrictionMapping"
    let enable = "LEBacklightMode"
    let recovery = "OriginalLogoSettings"
    var keys: [String] { [maximum, minimum, curve, enable] }
    var original: [String: Any]? { UserDefaults.standard.dictionary(forKey: recovery) }
    var timer: Timer?
    var started = Date()

    func fail(_ text: String) -> NSError {
        NSError(domain: "LogoLight", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
    }
    func set(_ key: String, _ value: Any) throws {
        guard lamp.write(value, key: key) else { throw fail("系统拒绝调整 Logo 灯。") }
    }
    func flat(_ nits: Double) -> [[Double]] { [[0, nits], [Double(Float.greatestFiniteMagnitude), nits]] }
    func brightness(_ factor: Double) throws {
        let nits = 1000 * pow(level / 100, 2) * factor
        try set(curve, flat(nits))
    }
    func restore() throws {
        timer?.invalidate()
        guard let original else { mode = .system; return }
        for key in keys {
            guard let value = original[key] else { throw fail("灯光设置备份不完整。") }
            try set(key, value)
        }
        UserDefaults.standard.removeObject(forKey: recovery)
        mode = .system
    }
    func select(_ next: Mode) {
        do {
            if next == .system { try restore(); message = ""; return }
            guard NSRunningApplication.runningApplications(withBundleIdentifier: "co.supershort.backglow").isEmpty else {
                message = "请先退出 Backglow，再选择灯光模式。"; return
            }
            if original == nil {
                var saved = [String: Any]()
                for key in keys {
                    guard let value = lamp.read(key) else { throw fail("这台 Mac 当前没有可用的 Logo 灯接口。") }
                    saved[key] = value
                }
                UserDefaults.standard.set(saved, forKey: recovery)
                UserDefaults.standard.synchronize()
            }
            timer?.invalidate()
            try set(maximum, flat(1000))
            try set(minimum, flat(0))
            if next == .off { try set(curve, flat(0)) }
            else { try brightness(next == .breathe ? 0.05 : 1) }
            try set(enable, next == .off ? 0 : 2)
            mode = next
            message = ""
            if next == .breathe {
                started = Date()
                let tick = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                    guard let self else { return }
                    let wave = (1 - cos(Date().timeIntervalSince(self.started) * .pi / 2)) / 2
                    do { try self.brightness(0.05 + 0.95 * wave) }
                    catch { self.handle(error) }
                }
                RunLoop.main.add(tick, forMode: .common)
                timer = tick
            }
        } catch { handle(error) }
    }
    func handle(_ error: Error) {
        do { try restore(); message = error.localizedDescription }
        catch { message = "恢复失败，请再次点「恢复系统自动」。" }
    }
}
struct Panel: View {
    @ObservedObject var light: Controller
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().interpolation(.high).frame(width: 29, height: 29)
                    .accessibilityHidden(true)
                Text("徽光").font(.title2.bold())
                Spacer(); Text(light.mode.rawValue).foregroundStyle(.secondary) }
            Picker("灯效", selection: Binding(get: { light.mode }, set: light.select)) {
                ForEach([Controller.Mode.system, .steady, .breathe, .off], id: \.self) { Text($0.rawValue).tag($0) }
            }.labelsHidden().pickerStyle(.segmented)
            HStack { Text("亮度"); Spacer(); Text("\(Int(light.level))%").monospacedDigit() }
            Slider(value: Binding(get: { light.level }, set: { value in
                light.level = value
                if light.mode != .breathe { light.select(.steady) }
            }), in: 1...100, step: 1).accessibilityLabel("Logo 亮度")
            if !light.message.isEmpty { Text(light.message).foregroundStyle(.orange).font(.callout) }
            Divider()
            HStack { Button("恢复系统自动") { light.select(.system) }
                Spacer(); Button("退出") { NSApp.terminate(nil) } }
        }.padding(18).frame(width: 300)
    }
}
final class Delegate: NSObject, NSApplicationDelegate {
    let light = Controller()
    var item: NSStatusItem!
    let popover = NSPopover()
    func applicationDidFinishLaunching(_ notification: Notification) {
        if light.original != nil { light.select(.system) }
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "徽光")
        item.button?.toolTip = "徽光 · Logo 灯"
        item.button?.target = self
        item.button?.action = #selector(toggle)
        popover.contentViewController = NSHostingController(rootView: Panel(light: light))
        popover.behavior = .transient
    }
    @objc func toggle() {
        if popover.isShown { popover.performClose(nil) }
        else if let button = item.button { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        do { try light.restore(); return .terminateNow }
        catch { light.message = "恢复失败，请重试。"; return .terminateCancel }
    }
}
if CommandLine.arguments.contains("--check") {
    let light = Controller()
    func matches(_ key: String, _ value: Any) -> Bool {
        (light.lamp.read(key) as? NSObject)?.isEqual(value) == true
    }
    guard light.original == nil else { exit(2) }
    let before = light.keys.compactMap { light.lamp.read($0) }
    guard before.count == light.keys.count else { exit(2) }
    light.select(.steady)
    var passed = light.mode == .steady && matches(light.curve, light.flat(250))
    light.select(.breathe)
    RunLoop.current.run(until: Date().addingTimeInterval(0.6))
    let breathing = light.lamp.read(light.curve) as? [[Double]]
    passed = passed && light.mode == .breathe && (breathing?.first?.last ?? 0) > 12.5
    light.select(.off)
    passed = passed && light.mode == .off && matches(light.enable, 0)
    light.select(.system)
    let restored = zip(light.keys, before).allSatisfy { matches($0, $1) }
    print("灯光模式测试 \(passed)，原始参数恢复 \(restored)，\(light.message)")
    exit(passed && restored ? 0 : 1)
}
let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
