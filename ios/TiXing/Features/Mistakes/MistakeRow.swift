import SwiftUI

struct MistakeRow: View {
    let mistake: Mistake

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 6) {
                Text(mistake.knowledgeSummary.isEmpty ? mistake.question : mistake.knowledgeSummary)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    TagPill(text: mistake.subject.label, color: subjectColor)
                    TagPill(text: mistake.status.label, color: statusColor)
                    Spacer()
                    Text(mistake.createdAt.formatted(.dateTime.year().month().day()))
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(13)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.04), radius: 9, y: 3)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let path = mistake.imagePath, let ui = UIImage(contentsOfFile: path) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            Text(mistake.subject.emoji)
                .font(.system(size: 22))
                .frame(width: 54, height: 54)
                .background(Theme.softPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var subjectColor: Color {
        switch mistake.subject {
        case .math: return Theme.primary
        case .chinese: return Theme.secondary
        case .english: return Theme.gradientEnd
        case .science: return Theme.warning
        }
    }

    private var statusColor: Color {
        switch mistake.status {
        case .mastered: return Theme.secondary
        case .reviewing: return Theme.gradientEnd
        case .unmastered: return Theme.danger
        }
    }
}
