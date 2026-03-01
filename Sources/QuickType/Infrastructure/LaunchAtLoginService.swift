import Foundation
import ServiceManagement

enum LaunchAtLoginService {
    static func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                Logger.error("Failed to toggle launch at login: \(error.localizedDescription)")
            }
        }
    }
}
