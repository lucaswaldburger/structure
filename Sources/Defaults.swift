import Foundation
import AppKit
import ScreenSaver

enum Defaults {
    private static let moduleName = "Structure"

    private static var store: ScreenSaverDefaults {
        ScreenSaverDefaults(forModuleWithName: moduleName)!
    }

    static func registerDefaults() {
        store.register(defaults: [
            "DisplayPeriod":         30,
            "CacheSize":             100,
            "EnableInternetAccess":  true,
            "FullTextualAnnotation": true,
            "OnlyLoadLocalFiles":    false,
            "RenderMode":            RenderMode.ribbon.rawValue,
            "BackgroundColor":       "#000000",
        ])
    }

    static var displayPeriod: TimeInterval { TimeInterval(store.integer(forKey: "DisplayPeriod")) }
    static var cacheSize:     Int          { store.integer(forKey: "CacheSize") }
    static var enableInternet:  Bool       { store.bool(forKey: "EnableInternetAccess") }
    static var fullAnnotation:  Bool       { store.bool(forKey: "FullTextualAnnotation") }
    static var onlyLocal:       Bool       { store.bool(forKey: "OnlyLoadLocalFiles") }

    static var backgroundColor: NSColor {
        NSColor(hex: store.string(forKey: "BackgroundColor") ?? "#000000") ?? .black
    }

    static var renderMode: RenderMode {
        get { RenderMode(rawValue: store.integer(forKey: "RenderMode")) ?? .ribbon }
        set { store.set(newValue.rawValue, forKey: "RenderMode"); store.synchronize() }
    }

    static func write(_ values: [String: Any]) {
        for (k, v) in values { store.set(v, forKey: k) }
        store.synchronize()
    }
}
