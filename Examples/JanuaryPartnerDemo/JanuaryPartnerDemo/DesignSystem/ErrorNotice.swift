import January
import SwiftUI

struct ErrorNotice: View {
    let error: Error
    var retry: (() -> Void)?
    var identifier: String?
    var retryIdentifier: String?
    var detailsIdentifier: String?
    var detailsBodyIdentifier: String?

    private var title: String {
        guard let januaryError = error as? JanuaryError else { return "Couldn’t complete that request" }
        switch januaryError.category {
        case .authentication, .authorization: return "Couldn’t use the configured credentials"
        case .validation: return "Check the information you entered"
        case .notFound: return "No matching result was found"
        case .rateLimited: return "Too many requests"
        case .timeout: return "The request took too long"
        case .transport: return "Check your connection"
        case .server, .decoding: return "January couldn’t complete the request"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: "exclamationmark.circle")
                .font(.headline)
                .foregroundStyle(AppPalette.rust)
            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(AppPalette.body)
            if let januaryError = error as? JanuaryError,
               januaryError.requestID != nil || januaryError.httpStatus != nil {
                DisclosureGroup("Technical details") {
                    VStack(alignment: .leading) {
                        if let status = januaryError.httpStatus { LabeledContent("HTTP status", value: "\(status)") }
                        if let code = januaryError.code { LabeledContent("Error code", value: code) }
                        if let requestID = januaryError.requestID { LabeledContent("Request ID", value: requestID) }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(detailsBodyIdentifier ?? "")
                }
                .font(.footnote)
                .accessibilityIdentifier(detailsIdentifier ?? "")
            }
            if let retry {
                Button("Try again", action: retry)
                    .font(.headline)
                    .accessibilityIdentifier(retryIdentifier ?? "")
            }
        }
        .appCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier ?? "")
    }
}

#Preview {
    ErrorNotice(
        error: NSError(domain: "Demo", code: 1, userInfo: [NSLocalizedDescriptionKey: "The request could not be completed."]),
        retry: {}
    )
    .padding()
    .background(AppPalette.paper)
}
