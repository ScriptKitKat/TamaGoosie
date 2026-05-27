// TamaGoosie/Features/Challenges/ChallengeListSection.swift
import SwiftUI

/// Generic section header + row container for the Challenges tab.
/// Two `init`s specialize for `ChallengeRun` (Active) and `ChallengeTemplate` (Browse).
/// We use explicit `id:` key paths in `ForEach` so we avoid conflicting with the
/// implicit `Identifiable` conformance SwiftData provides via `PersistentIdentifier`.
struct ChallengeListSection<Item, RowContent: View>: View {
    enum Kind { case active, browse }

    let kind: Kind
    let items: [Item]
    let idKeyPath: KeyPath<Item, String>
    let row: (Item) -> RowContent

    init(
        _ kind: Kind,
        runs: [ChallengeRun],
        @ViewBuilder row: @escaping (ChallengeRun) -> RowContent
    ) where Item == ChallengeRun {
        self.kind = kind
        self.items = runs
        self.idKeyPath = \ChallengeRun.runId
        self.row = row
    }

    init(
        _ kind: Kind,
        templates: [ChallengeTemplate],
        @ViewBuilder row: @escaping (ChallengeTemplate) -> RowContent
    ) where Item == ChallengeTemplate {
        self.kind = kind
        self.items = templates
        self.idKeyPath = \ChallengeTemplate.templateId
        self.row = row
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
                .textCase(.uppercase)
            ForEach(items, id: idKeyPath) { item in
                row(item)
            }
        }
    }

    private var label: String { kind == .active ? "Active" : "Browse" }
}
