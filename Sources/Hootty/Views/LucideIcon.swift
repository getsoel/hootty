import SwiftUI
import LucideIcons

struct LucideIcon: View {
    let image: NSImage
    let size: CGFloat

    init(_ image: NSImage, size: CGFloat) {
        self.image = image
        self.size = size
    }

    var body: some View {
        Image(nsImage: image)
            .renderingMode(.template)
            .resizable()
            .frame(width: size, height: size)
    }
}
