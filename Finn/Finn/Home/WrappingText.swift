import SwiftUI

/// System text with explicit multiline measurement. UIKit keeps its text-layout and
/// accessibility bounds in agreement inside scaled sheet presentations on iOS 27.
struct WrappingText: UIViewRepresentable {
    let text: String
    var style: UIFont.TextStyle = .body
    var weight: UIFont.Weight?
    var color: UIColor = .label
    var alignment: NSTextAlignment = .natural

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.text = text
        label.textAlignment = alignment
        label.semanticContentAttribute = context.environment.layoutDirection == .rightToLeft
            ? .forceRightToLeft : .forceLeftToRight
        let traits = label.traitCollection.modifyingTraits {
            $0.preferredContentSizeCategory = UIContentSizeCategory(context.environment.dynamicTypeSize)
            $0.userInterfaceStyle = .dark
        }
        label.textColor = color.resolvedColor(with: traits)
        let font = UIFont.preferredFont(forTextStyle: style, compatibleWith: traits)
        if let weight {
            let descriptor = font.fontDescriptor.addingAttributes([
                .traits: [UIFontDescriptor.TraitKey.weight: weight.rawValue]
            ])
            label.font = UIFont(descriptor: descriptor, size: 0)
        } else {
            label.font = font
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let width = max(1, proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? ceil(uiView.intrinsicContentSize.width))
        let fit = uiView.sizeThatFits(CGSize(width: max(1, width), height: .greatestFiniteMagnitude))
        // Leave room for fractional glyph advances when a sheet scales its contents.
        return CGSize(width: min(width, ceil(fit.width)), height: ceil(fit.height))
    }
}
