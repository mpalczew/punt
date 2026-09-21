import Darwin
import Foundation

final class SingleInstanceCoordinator {
    enum ClaimResult {
        case acquired
        case alreadyRunning
        case unavailable(Int32)
    }

    private static let notificationName = Notification.Name(
        "com.punt.browser-picker.forward-urls"
    )
    private static let lockFileName = "com.punt.browser-picker.instance.lock"

    private var lockFileDescriptor: Int32 = -1
    private var observer: NSObjectProtocol?

    var onForwardedURL: ((URL) -> Void)?

    deinit {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        if lockFileDescriptor >= 0 {
            close(lockFileDescriptor)
        }
    }

    func claim() -> ClaimResult {
        let lockURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(Self.lockFileName)
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)

        guard descriptor >= 0 else {
            return .unavailable(errno)
        }

        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            let error = errno
            close(descriptor)
            return error == EWOULDBLOCK ? .alreadyRunning : .unavailable(error)
        }

        lockFileDescriptor = descriptor
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Self.notificationName,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let values = notification.userInfo?["urls"] as? [String] else { return }
            for value in values {
                guard let url = URL(string: value) else { continue }
                self?.onForwardedURL?(url)
            }
        }
        return .acquired
    }

    func forward(urls: [URL]) {
        guard !urls.isEmpty else { return }
        DistributedNotificationCenter.default().post(
            name: Self.notificationName,
            object: nil,
            userInfo: ["urls": urls.map(\.absoluteString)]
        )
    }
}
