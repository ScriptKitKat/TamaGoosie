import SwiftUI

struct GoalCategorySheet: View {
    @Binding var selectedCategory: GoalCategory
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose a category")
                        .font(GoosieTheme.bodyFont())
                        .foregroundStyle(GoosieTheme.charcoalOutline)
                        .padding(.horizontal, GoosieTheme.padding)

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(GoalCategory.allCases, id: \.self) { cat in
                            categoryCell(cat)
                        }
                    }
                    .padding(.horizontal, GoosieTheme.padding)
                }
                .padding(.top, 16)
            }
            .background(GoosieTheme.mintBackground.ignoresSafeArea())
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .preferredColorScheme(.light)
        }
        .presentationDetents([.medium])
    }

    private func categoryCell(_ cat: GoalCategory) -> some View {
        let isSelected = selectedCategory == cat
        let chipColor = Color(hex: UInt(cat.color, radix: 16) ?? 0xFFD93D)

        return Button {
            selectedCategory = cat
        } label: {
            VStack(spacing: 4) {
                Image(systemName: cat.icon)
                    .font(.system(size: 20))
                Text(cat.displayName)
                    .font(GoosieTheme.captionFont(10))
            }
            .foregroundStyle(isSelected ? .white : GoosieTheme.charcoalOutline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? chipColor : chipColor.opacity(0.15))
            )
        }
    }
}
