import SwiftUI

struct TerminalInputField: View {
    let session: PTYSession
    @State private var input = ""

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.system(size: 12, weight: .bold, design: .monospaced))

            TextField("Type a command...", text: $input)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .onSubmit {
                    guard !input.isEmpty else { return }
                    session.send(input + "\n")
                    input = ""
                }
                .disabled(!session.isRunning)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
