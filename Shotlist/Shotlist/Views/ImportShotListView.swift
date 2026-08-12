import SwiftUI

struct ImportShotListView: View {
    @EnvironmentObject private var store: ShotListStore
    @State private var pastedText = ""
    @State private var projectTitle = ""
    @State private var showPreview = false
    @State private var previewProject: ShotListProject?
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        Form {
            Section {
                TextField("Project title (optional)", text: $projectTitle)
            } header: {
                Text("Project")
            }

            Section {
                ZStack(alignment: .topLeading) {
                    if pastedText.isEmpty {
                        Text("Paste your shot list here…\n\nCategories in CAPS, shots with ☐ or - prefixes.")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    TextEditor(text: $pastedText)
                        .frame(minHeight: 280)
                        .focused($isEditorFocused)
                }
            } header: {
                Text("Shot List")
            } footer: {
                Text("Supports checkbox (☐), bullet (-), and numbered lists. ALL CAPS lines become categories.")
            }

            Section {
                Button("Load Sample (HIFK Töölö)") {
                    pastedText = SampleData.hifkTooloShotList
                    projectTitle = "HIFK-FILMI – B-ROLL Töölö"
                }

                Button("Preview Parse") {
                    previewProject = ShotListParser.parse(
                        pastedText,
                        projectTitle: projectTitle.isEmpty ? nil : projectTitle
                    )
                    showPreview = true
                }
                .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Create Shot List") {
                    let title = projectTitle.isEmpty ? nil : projectTitle
                    store.importFromPaste(pastedText, title: title)
                    pastedText = ""
                    projectTitle = ""
                }
                .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .fontWeight(.semibold)
            }
        }
        .navigationTitle("Import")
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isEditorFocused = false }
            }
        }
        .sheet(isPresented: $showPreview) {
            if let preview = previewProject {
                NavigationStack {
                    ShotListView(project: preview, isPreview: true)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showPreview = false }
                            }
                        }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ImportShotListView()
            .environmentObject(ShotListStore())
    }
}
