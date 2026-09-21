import Foundation

enum HomebrewDetector {
    private static let installedApplicationPath = "/Applications/Punt.app"

    static var isInstalledApplication: Bool {
        let bundlePath = Bundle.main.bundleURL.standardizedFileURL.path
        return bundlePath == installedApplicationPath || isHomebrewManaged
    }

    static var isHomebrewManaged: Bool {
        let bundlePath = Bundle.main.bundlePath
        let caskroomPaths = [
            "/opt/homebrew/Caskroom/punt",
            "/usr/local/Caskroom/punt",
        ]

        let fm = FileManager.default
        for caskroom in caskroomPaths {
            guard fm.fileExists(atPath: caskroom),
                  let versions = try? fm.contentsOfDirectory(atPath: caskroom) else { continue }
            for version in versions where version != ".metadata" {
                let symlinkPath = "\(caskroom)/\(version)/Punt.app"
                if let dest = try? fm.destinationOfSymbolicLink(atPath: symlinkPath),
                   dest == bundlePath {
                    return true
                }
            }
        }
        return false
    }
}
