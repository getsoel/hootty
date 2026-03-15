import HoottyCore
import SwiftUI

struct TemplatesView: View {
    let tokens: DesignTokens

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 32))
                .foregroundStyle(Color(tokens.textMuted).opacity(0.4))
            Text("Templates")
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.textMuted))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(tokens.surface))
    }
}
