import Foundation
import Security

enum UpdateInstaller {
    enum InstallError: Error {
        case downloadFailed(Error?)
        case unzipFailed
        case noAppBundleInZip
        case signatureInvalid(String)
        case teamIDMismatch(expected: String, got: String)
        case replaceFailed(Error)
    }

    static let expectedTeamID: String = {
        guard let code = staticCode(for: Bundle.main.bundleURL),
              let info = signingInfo(for: code),
              let teamID = info[kSecCodeInfoTeamIdentifier as String] as? String else {
            return "FS3CWH8867"
        }
        return teamID
    }()

    static func downloadAndInstall(
        from url: URL,
        completion: @escaping (Result<Void, InstallError>) -> Void
    ) {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
            .appendingPathComponent("com.punt.browser-picker.update")
            .appendingPathComponent(UUID().uuidString)

        URLSession.shared.downloadTask(with: url) { localURL, response, error in
            guard let localURL = localURL else {
                completion(.failure(.downloadFailed(error)))
                return
            }

            do {
                try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

                let zipPath = tempDir.appendingPathComponent("update.zip")
                try fm.moveItem(at: localURL, to: zipPath)

                let extractDir = tempDir.appendingPathComponent("extracted")
                try fm.createDirectory(at: extractDir, withIntermediateDirectories: true)

                let ditto = Process()
                ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                ditto.arguments = ["-xk", zipPath.path, extractDir.path]
                try ditto.run()
                ditto.waitUntilExit()

                guard ditto.terminationStatus == 0 else {
                    cleanup(tempDir)
                    completion(.failure(.unzipFailed))
                    return
                }

                let contents = try fm.contentsOfDirectory(
                    at: extractDir, includingPropertiesForKeys: nil
                )
                guard let newAppURL = contents.first(where: {
                    $0.lastPathComponent == "Punt.app"
                }) else {
                    cleanup(tempDir)
                    completion(.failure(.noAppBundleInZip))
                    return
                }

                if let error = verifySignature(of: newAppURL) {
                    cleanup(tempDir)
                    completion(.failure(error))
                    return
                }

                _ = try fm.replaceItemAt(
                    Bundle.main.bundleURL,
                    withItemAt: newAppURL
                )

                cleanup(tempDir)
                completion(.success(()))
            } catch {
                cleanup(tempDir)
                completion(.failure(.replaceFailed(error)))
            }
        }.resume()
    }

    private static func verifySignature(of appURL: URL) -> InstallError? {
        guard let code = staticCode(for: appURL) else {
            return .signatureInvalid("Could not create static code reference")
        }

        let validateStatus = SecStaticCodeCheckValidity(
            code,
            SecCSFlags(rawValue: kSecCSCheckAllArchitectures),
            nil
        )
        guard validateStatus == errSecSuccess else {
            return .signatureInvalid("Validation failed: \(validateStatus)")
        }

        guard let info = signingInfo(for: code),
              let teamID = info[kSecCodeInfoTeamIdentifier as String] as? String else {
            return .signatureInvalid("Could not extract team identifier")
        }

        guard teamID == expectedTeamID else {
            return .teamIDMismatch(expected: expectedTeamID, got: teamID)
        }

        return nil
    }

    private static func staticCode(for url: URL) -> SecStaticCode? {
        var code: SecStaticCode?
        SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &code)
        return code
    }

    private static func signingInfo(for code: SecStaticCode) -> [String: Any]? {
        var info: CFDictionary?
        let status = SecCodeCopySigningInformation(
            code, SecCSFlags(rawValue: kSecCSSigningInformation), &info
        )
        guard status == errSecSuccess else { return nil }
        return info as? [String: Any]
    }

    private static func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }
}
