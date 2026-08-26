import SwiftUI

struct NetworkImage: View {
    private let url: URL?
    private let placeholder: Image
    private let contentMode: ContentMode

    init(url: String?, placeholder: Image, contentMode: ContentMode = .fill) {
        self.url = url.flatMap(URL.init(string:))
        self.placeholder = placeholder
        self.contentMode = contentMode
    }

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
        }
    }
}

#Preview {
    NetworkImage(
        url: nil,
        placeholder: Image(systemName: "photo")
    )
    .foregroundStyle(AppPalette.green)
    .frame(width: 80, height: 80)
    .background(AppPalette.control)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
}
