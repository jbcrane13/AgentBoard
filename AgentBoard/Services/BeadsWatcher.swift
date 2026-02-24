import Dispatch
import Darwin
import Foundation

final class BeadsWatcher {
    private let queue = DispatchQueue(label: "com.agentboard.beads-watcher")
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1

    deinit {
        stop()
    }

    func watch(
        fileURL: URL,
        onChange: @escaping @Sendable () -> Void,
        onError: ((String) -> Void)? = nil
    ) {
        stop()

        fileDescriptor = open(fileURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            let reason = String(cString: strerror(errno))
            onError?("Unable to watch \(fileURL.lastPathComponent): \(reason)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete, .extend],
            queue: queue
        )

        source.setEventHandler(handler: onChange)
        source.setCancelHandler { [weak self] in
            guard let self, self.fileDescriptor >= 0 else { return }
            close(self.fileDescriptor)
            self.fileDescriptor = -1
        }

        self.source = source
        source.resume()
    }

    func stop() {
        source?.cancel()
        source = nil
    }
}
