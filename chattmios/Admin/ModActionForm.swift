import SwiftUI

struct ModActionForm: View {
    let action: ModAction
    var onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(action.fields) { field in
                        TextField(field.placeholder, text: binding(for: field.key), axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }
                Section {
                    Text(preview).font(.system(.footnote, design: .monospaced)).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(action.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Run") { onSubmit(preview) }
                        .disabled(!isValid)
                }
            }
        }
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
