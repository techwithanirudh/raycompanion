import Observation
import Foundation

@MainActor @Observable final class Settings {
    var interceptTab: Bool { didSet { if !isTesting { UserDefaults.standard.set(interceptTab, forKey: "interceptTab") } } }
    let isTesting: Bool
    init(testing: Bool) {
        isTesting = testing
        if !testing { UserDefaults.standard.register(defaults: ["interceptTab": true]) }
        interceptTab = testing ? false : UserDefaults.standard.bool(forKey: "interceptTab")
    }
}
