import SwiftUI

struct ModActionForm: View {
    let action: ModAction
    var onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String] = [:]

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text(action.title).font(.headline)
                Spacer()
                Button("Run") { onSubmit(preview) }
                    .disabled(!isValid)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Divider()
            formContent
        }
        .frame(minWidth: 360, minHeight: 200)
        .dismissOnOutsideClick { dismiss() }
        #else
        NavigationStack {
            formContent
                .navigationTitle(action.title)
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Run") { onSubmit(preview) }.disabled(!isValid)
                    }
                }
        }
        #endif
    }

    private var formContent: some View {
        Form {
            Section {
                ForEach(action.fields) { field in
                    TextField(field.placeholder, text: binding(for: field.key), axis: .vertical)
                        .noAutocapitalization()
                        .autocorrectionDisabled()
                }
            }
            Section {
                Text(preview)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })
    }

    private var isValid: Bool {
        action.fields.allSatisfy { !$0.required || !(values[$0.key] ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var preview: String {
        let args = action.fields
            .map { values[$0.key]?.trimmingCharacters(in: .whitespaces) ?? "" }
            .filter { !$0.isEmpty }
        return ([action.command] + args).joined(separator: " ")
    }
}
