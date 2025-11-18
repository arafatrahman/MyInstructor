// File: arafatrahman/myinstructor/MyInstructor-main/MyInstructor/Common/Views/FlowLayout.swift
// --- NEW HELPER FILE ---

import SwiftUI

/// A View layout that arranges its children in a flow, wrapping to new lines as needed.
struct FlowLayout: Layout {
    var alignment: Alignment
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        let effectiveWidth = (proposal.width ?? 0) - (spacing * 2)

        for size in sizes {
            if lineWidth + size.width + spacing > effectiveWidth && lineWidth > 0 {
                totalHeight += lineHeight + spacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            totalWidth = max(totalWidth, lineWidth)
        }
        totalHeight += lineHeight
        return .init(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var (x, y) = (bounds.minX, bounds.minY)
        var lineHeight: CGFloat = 0

        for index in subviews.indices {
            if x + sizes[index].width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }

            subviews[index].place(
                at: .init(x: x, y: y),
                anchor: .topLeading,
                proposal: .init(sizes[index])
            )

            lineHeight = max(lineHeight, sizes[index].height)
            x += sizes[index].width + spacing
        }
    }
}
