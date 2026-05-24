import AgentBoardCore
import Foundation
import Testing

struct ChatEndpointValidatorTests {
    @Test func rejectsHermesEndpointPointedAtCompanion() throws {
        let validator = ChatEndpointValidator()

        #expect(throws: ChatEndpointValidationError.self) {
            try validator.validate(
                hermesGatewayURL: "http://127.0.0.1:8742/v1",
                companionURL: "http://127.0.0.1:8742"
            )
        }
    }

    @Test func rejectsHTTPSForPrivateHermesHost() throws {
        let validator = ChatEndpointValidator()

        #expect(throws: ChatEndpointValidationError.self) {
            try validator.validate(
                hermesGatewayURL: "https://100.80.1.1:8642",
                companionURL: "http://127.0.0.1:8742"
            )
        }
    }

    @Test func allowsHTTPSForPublicHermesHost() throws {
        let validator = ChatEndpointValidator()

        try validator.validate(
            hermesGatewayURL: "https://api.example.com:8642",
            companionURL: "http://127.0.0.1:8742"
        )
    }

    @Test func uploadEndpointStripsTrailingV1Path() {
        let validator = ChatEndpointValidator()
        let url = validator.uploadEndpointURL(hermesGatewayURL: "http://127.0.0.1:8642/v1")

        #expect(url.absoluteString == "http://127.0.0.1:8642/v1/upload")
    }
}
