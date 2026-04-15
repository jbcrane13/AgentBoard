import Foundation
import SwiftData

@Model
final class Attachment: Identifiable {
    @Attribute(.unique) var id: UUID
    var filename: String
    var fileExtension: String
    var fileSize: Int64
    var mimeType: String
    var thumbnailData: Data?
    var createdAt: Date
    var issueNumber: Int
    var projectName: String
    var storagePath: String

    init(
        id: UUID = UUID(),
        filename: String,
        fileExtension: String,
        fileSize: Int64,
        mimeType: String,
        thumbnailData: Data? = nil,
        createdAt: Date = .now,
        issueNumber: Int,
        projectName: String,
        storagePath: String
    ) {
        self.id = id
        self.filename = filename
        self.fileExtension = fileExtension
        self.fileSize = fileSize
        self.mimeType = mimeType
        self.thumbnailData = thumbnailData
        self.createdAt = createdAt
        self.issueNumber = issueNumber
        self.projectName = projectName
        self.storagePath = storagePath
    }
}

// MARK: - Convenience

extension Attachment {
    var fullFilename: String {
        "\(filename).\(fileExtension)"
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var isImage: Bool {
        mimeType.hasPrefix("image/")
    }

    var isPDF: Bool {
        mimeType == "application/pdf"
    }
}

// MARK: - Samples

extension Attachment {
    static func sample(
        filename: String = "screenshot",
        fileExtension: String = "png",
        mimeType: String = "image/png",
        issueNumber: Int = 1,
        projectName: String = "AgentBoard"
    ) -> Attachment {
        Attachment(
            filename: filename,
            fileExtension: fileExtension,
            fileSize: 245_760,
            mimeType: mimeType,
            issueNumber: issueNumber,
            projectName: projectName,
            storagePath: "attachments/\(projectName)/\(issueNumber)/\(filename).\(fileExtension)"
        )
    }

    @MainActor
    static var preview: ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Attachment.self, configurations: config)
        let context = container.mainContext

        let attachments = [
            Attachment(
                filename: "crash-log",
                fileExtension: "txt",
                fileSize: 12_288,
                mimeType: "text/plain",
                issueNumber: 42,
                projectName: "NetMonitor",
                storagePath: "attachments/NetMonitor/42/crash-log.txt"
            ),
            Attachment(
                filename: "ui-mockup",
                fileExtension: "png",
                fileSize: 512_000,
                mimeType: "image/png",
                issueNumber: 15,
                projectName: "AgentBoard",
                storagePath: "attachments/AgentBoard/15/ui-mockup.png"
            ),
            Attachment(
                filename: "design-spec",
                fileExtension: "pdf",
                fileSize: 1_048_576,
                mimeType: "application/pdf",
                issueNumber: 15,
                projectName: "AgentBoard",
                storagePath: "attachments/AgentBoard/15/design-spec.pdf"
            )
        ]

        for attachment in attachments {
            context.insert(attachment)
        }

        return container
    }
}
