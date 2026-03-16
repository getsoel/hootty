import HoottyCore
import PipelineKit
import SwiftUI

struct TemplateEditorView: View {
    let tokens: DesignTokens

    @State private var templates: [(name: String, config: PipelineConfig)] = []
    @State private var selectedName: String?
    @State private var editingName: String = ""
    @State private var editingMaxClaims: String = ""
    @State private var showDeleteAlert = false
    @State private var showResetAlert = false
    @State private var hoverName: String?

    private let store = TemplateStore(rootPath: TemplateStore.defaultDirectory)

    private var selectedTemplate: (name: String, config: PipelineConfig)? {
        templates.first { $0.name == selectedName }
    }

    var body: some View {
        if templates.isEmpty {
            emptyState
        } else {
            HStack(spacing: 0) {
                templateList
                Rectangle().fill(Color(tokens.border)).frame(width: 1)
                templateDetail
            }
            .background(Color(tokens.surface))
            .onAppear(perform: initialLoad)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 32))
                .foregroundStyle(Color(tokens.textMuted).opacity(0.4))
            Text("No templates")
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.textMuted))
            Button("Reset Defaults") {
                store.seedDefaults()
                reloadTemplates()
            }
            .buttonStyle(.plain)
            .font(.system(size: TypeScale.captionSize, weight: .medium))
            .foregroundStyle(Color(tokens.textAccent))
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(tokens.textAccent).opacity(0.1))
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(tokens.surface))
        .onAppear(perform: initialLoad)
    }

    // MARK: - Template List

    private var templateList: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(templates, id: \.name) { template in
                        templateListRow(name: template.name)
                    }
                }
                .padding(.vertical, Spacing.sm)
            }

            Spacer(minLength: 0)

            Button {
                createTemplate()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "plus")
                        .font(.system(size: TypeScale.smallSize))
                    Text("New Template")
                        .font(.system(size: TypeScale.captionSize))
                }
                .foregroundStyle(Color(tokens.textAccent))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay(alignment: .top) {
                Rectangle().fill(Color(tokens.border)).frame(height: 1)
            }
        }
        .frame(width: 200)
        .background(Color(tokens.surface))
    }

    private func templateListRow(name: String) -> some View {
        let isSelected = selectedName == name
        let isHover = hoverName == name
        let displayName = displayNameFor(name)

        return HStack(spacing: Spacing.md) {
            Text(displayName)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(isSelected ? tokens.elementSelectedText : tokens.text))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.smd)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color(tokens.elementSelected) : (isHover ? Color(tokens.elementHover) : Color.clear))
                .padding(.horizontal, Spacing.sm)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectTemplate(name: name)
        }
        .onHover { hovering in
            hoverName = hovering ? name : nil
        }
        .contextMenu {
            Button("Duplicate") { duplicateTemplate(name: name) }
            Divider()
            Button("Delete", role: .destructive) {
                deleteTemplate(name: name)
            }
            .disabled(templates.count <= 1)
        }
    }

    // MARK: - Template Detail

    @ViewBuilder
    private var templateDetail: some View {
        if let template = selectedTemplate {
            templateDetailContent(template: template)
        } else {
            Text("Select a template")
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.textMuted))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func templateDetailContent(template: (name: String, config: PipelineConfig)) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                nameSection(template: template)
                stagesSection(template: template)
                settingsSection(template: template)
                actionsSection(template: template)
            }
            .padding(Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(tokens.surface))
    }

    // MARK: - Name Section

    private func nameSection(template: (name: String, config: PipelineConfig)) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Name")
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(tokens.textMuted))
            TextField("Template name", text: $editingName)
                .textFieldStyle(.plain)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.text))
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(tokens.surfaceHighlight).opacity(0.3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(tokens.border), lineWidth: 1)
                )
                .onSubmit {
                    renameTemplate(from: template.name, to: editingName)
                }
        }
    }

    // MARK: - Stages Section

    private func stagesSection(template: (name: String, config: PipelineConfig)) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Stages")
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(tokens.textMuted))

            VStack(spacing: 0) {
                ForEach(Array(template.config.stages.enumerated()), id: \.offset) { index, stage in
                    stageRow(templateName: template.name, config: template.config, index: index, stage: stage)
                    if index < template.config.stages.count - 1 {
                        Rectangle().fill(Color(tokens.border).opacity(0.5)).frame(height: 1)
                            .padding(.horizontal, Spacing.md)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(tokens.surfaceHighlight).opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(tokens.border), lineWidth: 1)
            )

            Button {
                addStage(templateName: template.name, config: template.config)
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "plus")
                        .font(.system(size: TypeScale.smallSize))
                    Text("Add Stage")
                        .font(.system(size: TypeScale.captionSize))
                }
                .foregroundStyle(Color(tokens.textAccent))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func stageRow(templateName: String, config: PipelineConfig, index: Int, stage: PipelineKit.Stage) -> some View {
        StageRowView(
            tokens: tokens,
            stage: stage,
            canDelete: config.stages.count > 2,
            onNameChange: { newName in
                var updated = config
                updated.stages[index].name = newName
                saveConfig(name: templateName, config: updated)
            },
            onTypeToggle: {
                var updated = config
                updated.stages[index].type = stage.type == .automated ? .manual : .automated
                if updated.stages[index].type == .manual {
                    updated.stages[index].command = nil
                }
                saveConfig(name: templateName, config: updated)
            },
            onCommandChange: { newCommand in
                var updated = config
                updated.stages[index].command = newCommand.isEmpty ? nil : newCommand
                saveConfig(name: templateName, config: updated)
            },
            onDelete: {
                var updated = config
                updated.stages.remove(at: index)
                saveConfig(name: templateName, config: updated)
            },
            onMoveUp: index > 0 ? {
                var updated = config
                updated.stages.swapAt(index, index - 1)
                saveConfig(name: templateName, config: updated)
            } : nil,
            onMoveDown: index < config.stages.count - 1 ? {
                var updated = config
                updated.stages.swapAt(index, index + 1)
                saveConfig(name: templateName, config: updated)
            } : nil
        )
    }

    // MARK: - Settings Section

    private func settingsSection(template: (name: String, config: PipelineConfig)) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Settings")
                .font(.system(size: TypeScale.captionSize))
                .foregroundStyle(Color(tokens.textMuted))

            Toggle("Pause on error", isOn: Binding(
                get: { template.config.settings.pauseOnError },
                set: { newValue in
                    var updated = template.config
                    updated.settings.pauseOnError = newValue
                    saveConfig(name: template.name, config: updated)
                }
            ))
            .font(.system(size: TypeScale.bodySize))
            .foregroundStyle(Color(tokens.text))
            .toggleStyle(.switch)
            .tint(Color(tokens.textAccent))

            HStack(spacing: Spacing.md) {
                Text("Max claims")
                    .font(.system(size: TypeScale.bodySize))
                    .foregroundStyle(Color(tokens.text))

                TextField("Unlimited", text: $editingMaxClaims)
                    .textFieldStyle(.plain)
                    .font(.system(size: TypeScale.bodySize))
                    .foregroundStyle(Color(tokens.text))
                    .frame(width: 60)
                    .padding(Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(tokens.surfaceHighlight).opacity(0.3))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(tokens.border), lineWidth: 1)
                    )
                    .onSubmit {
                        var updated = template.config
                        updated.settings.maxClaims = Int(editingMaxClaims)
                        saveConfig(name: template.name, config: updated)
                    }
            }
        }
    }

    // MARK: - Actions Section

    private func actionsSection(template: (name: String, config: PipelineConfig)) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Button("Delete Template") {
                showDeleteAlert = true
            }
            .buttonStyle(.plain)
            .font(.system(size: TypeScale.captionSize, weight: .medium))
            .foregroundStyle(Color(tokens.statusError))
            .disabled(templates.count <= 1)
            .alert("Delete template?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteTemplate(name: template.name)
                }
            } message: {
                Text("Delete template \"\(displayNameFor(template.name))\"? This cannot be undone.")
            }

            Button("Reset Defaults") {
                showResetAlert = true
            }
            .buttonStyle(.plain)
            .font(.system(size: TypeScale.captionSize, weight: .medium))
            .foregroundStyle(Color(tokens.textMuted))
            .alert("Reset default templates?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    resetDefaults()
                }
            } message: {
                Text("This will overwrite any customizations to simple, review, and full-ci templates.")
            }
        }
    }

    // MARK: - Actions

    private func initialLoad() {
        store.seedDefaults()
        reloadTemplates()
    }

    private func reloadTemplates() {
        templates = store.listTemplates().compactMap { name in
            guard let config = try? store.loadTemplate(name: name) else { return nil }
            return (name: name, config: config)
        }
        if let selected = selectedName, templates.contains(where: { $0.name == selected }) {
            syncEditingState(for: selected)
        } else if let first = templates.first {
            selectTemplate(name: first.name)
        }
    }

    private func selectTemplate(name: String) {
        selectedName = name
        syncEditingState(for: name)
    }

    private func syncEditingState(for name: String) {
        editingName = displayNameFor(name)
        if let config = templates.first(where: { $0.name == name })?.config {
            editingMaxClaims = config.settings.maxClaims.map(String.init) ?? ""
        }
    }

    private func saveConfig(name: String, config: PipelineConfig) {
        try? store.saveTemplate(name: name, config: config)
        reloadTemplates()
    }

    private func createTemplate() {
        let name = uniqueName("untitled")
        let config = PipelineTemplate.review.config
        try? store.saveTemplate(name: name, config: config)
        reloadTemplates()
        selectTemplate(name: name)
    }

    private func duplicateTemplate(name: String) {
        guard let config = try? store.loadTemplate(name: name) else { return }
        let copyName = uniqueName("\(name)-copy")
        try? store.saveTemplate(name: copyName, config: config)
        reloadTemplates()
        selectTemplate(name: copyName)
    }

    private func deleteTemplate(name: String) {
        guard templates.count > 1 else { return }
        try? store.deleteTemplate(name: name)
        if selectedName == name {
            selectedName = nil
        }
        reloadTemplates()
    }

    private func renameTemplate(from oldName: String, to displayName: String) {
        let newSlug = deriveSlug(from: displayName)
        guard !newSlug.isEmpty, newSlug != oldName else {
            editingName = displayNameFor(oldName)
            return
        }
        let finalSlug = uniqueName(newSlug, excluding: oldName)
        guard let config = try? store.loadTemplate(name: oldName) else { return }
        try? store.saveTemplate(name: finalSlug, config: config)
        try? store.deleteTemplate(name: oldName)
        selectedName = finalSlug
        reloadTemplates()
    }

    private func resetDefaults() {
        for template in PipelineTemplate.allCases {
            try? store.saveTemplate(name: template.rawValue, config: template.config)
        }
        reloadTemplates()
    }

    private func addStage(templateName: String, config: PipelineConfig) {
        var updated = config
        updated.stages.append(PipelineKit.Stage(name: "New Stage", type: .manual))
        saveConfig(name: templateName, config: updated)
    }

    // MARK: - Helpers

    private func uniqueName(_ base: String, excluding: String? = nil) -> String {
        let existing = Set(templates.map(\.name).filter { $0 != excluding })
        guard existing.contains(base) else { return base }
        var counter = 2
        while existing.contains("\(base)-\(counter)") {
            counter += 1
        }
        return "\(base)-\(counter)"
    }

    private func displayNameFor(_ slug: String) -> String {
        slug.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}

// MARK: - Stage Row View

private struct StageRowView: View {
    let tokens: DesignTokens
    let stage: PipelineKit.Stage
    let canDelete: Bool
    var onNameChange: (String) -> Void
    var onTypeToggle: () -> Void
    var onCommandChange: (String) -> Void
    var onDelete: () -> Void
    var onMoveUp: (() -> Void)?
    var onMoveDown: (() -> Void)?

    @State private var editingStage: String = ""
    @State private var editingCommand: String = ""
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            mainRow
            if stage.type == .automated {
                commandRow
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.smd)
        .onHover { isHovering = $0 }
        .onAppear {
            editingStage = stage.name
            editingCommand = stage.command ?? ""
        }
        .onChange(of: stage.name) { _, newValue in editingStage = newValue }
        .onChange(of: stage.command) { _, newValue in editingCommand = newValue ?? "" }
    }

    private var mainRow: some View {
        HStack(spacing: Spacing.md) {
            VStack(spacing: 0) {
                Button {
                    onMoveUp?()
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 16, height: 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(tokens.textMuted).opacity(onMoveUp != nil ? 0.8 : 0.2))
                .disabled(onMoveUp == nil)

                Button {
                    onMoveDown?()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 16, height: 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(tokens.textMuted).opacity(onMoveDown != nil ? 0.8 : 0.2))
                .disabled(onMoveDown == nil)
            }

            TextField("Stage name", text: $editingStage)
                .textFieldStyle(.plain)
                .font(.system(size: TypeScale.bodySize))
                .foregroundStyle(Color(tokens.text))
                .onSubmit {
                    let trimmed = editingStage.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else {
                        editingStage = stage.name
                        return
                    }
                    onNameChange(trimmed)
                }

            Spacer()

            Button {
                onTypeToggle()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: stage.type == .automated ? "bolt.fill" : "hand.raised.fill")
                        .font(.system(size: 9))
                    Text(stage.type == .automated ? "auto" : "manual")
                        .font(.system(size: TypeScale.captionSize))
                }
                .foregroundStyle(Color(tokens.textMuted))
                .padding(.horizontal, Spacing.smd)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule().fill(Color(tokens.surfaceHighlight).opacity(0.3))
                )
            }
            .buttonStyle(.plain)

            Button {
                onDelete()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(tokens.textMuted))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isHovering && canDelete ? 1 : 0)
        }
    }

    private var commandRow: some View {
        TextField("Command (e.g. /commit)", text: $editingCommand)
            .textFieldStyle(.plain)
            .font(.system(size: TypeScale.captionSize))
            .foregroundStyle(Color(tokens.text))
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(tokens.surfaceHighlight).opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(tokens.border).opacity(0.5), lineWidth: 1)
            )
            .padding(.leading, 28)
            .onSubmit {
                onCommandChange(editingCommand)
            }
    }
}
