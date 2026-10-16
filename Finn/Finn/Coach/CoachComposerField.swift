import SwiftUI
import UIKit

/// The editor and its Send control share one native view. This keeps their hit targets and
/// current text together while the keyboard and the surrounding tab controller change size.
struct CoachComposerField: UIViewRepresentable {
    var isAnswering: Bool
    var onSubmit: (String) -> Bool
    var onStop: () -> Void
    var onFocus: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> ComposerView {
        let view = ComposerView()
        view.editor.delegate = context.coordinator
        view.action.addTarget(
            context.coordinator,
            action: #selector(Coordinator.performAction),
            for: .touchUpInside
        )
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.tintColor = UIColor(AppPageStyle.tint)
        let done = UIBarButtonItem(
            title: String(localized: "Done"),
            style: .prominent,
            target: context.coordinator,
            action: #selector(Coordinator.dismissKeyboard)
        )
        done.accessibilityIdentifier = "coach.dismissKeyboard"
        toolbar.items = [.flexibleSpace(), done]
        view.editor.inputAccessoryView = toolbar
        context.coordinator.view = view
        view.refresh(isAnswering: isAnswering)
        return view
    }

    func updateUIView(_ view: ComposerView, context: Context) {
        context.coordinator.parent = self
        view.refresh(isAnswering: isAnswering)
    }

    static func dismantleUIView(_ view: ComposerView, coordinator: Coordinator) {
        view.editor.delegate = nil
        view.editor.resignFirstResponder()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ComposerView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else {
            return nil
        }
        return CGSize(width: width, height: uiView.height(for: width))
    }

    final class ComposerView: UIView {
        let editor = UITextView()
        let action = UIButton(type: .system)
        private let placeholder = UILabel()

        override init(frame: CGRect) {
            super.init(frame: frame)
            let card = UIView()
            card.backgroundColor = UIColor(HomeStyle.card)
            card.layer.cornerRadius = 18
            editor.backgroundColor = .clear
            editor.font = .preferredFont(forTextStyle: .body)
            editor.adjustsFontForContentSizeCategory = true
            editor.textColor = .label
            editor.tintColor = UIColor(AppPageStyle.tint)
            editor.textContainerInset = .zero
            editor.textContainer.lineFragmentPadding = 0
            editor.returnKeyType = .send
            editor.enablesReturnKeyAutomatically = true
            editor.accessibilityIdentifier = "coach.field"
            editor.accessibilityLabel = String(localized: "Ask about your sets")
            editor.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            placeholder.text = String(localized: "Ask about your sets")
            placeholder.font = editor.font
            placeholder.adjustsFontForContentSizeCategory = true
            placeholder.textColor = UIColor(HomeStyle.supportingText)
            placeholder.isUserInteractionEnabled = false
            placeholder.isAccessibilityElement = false
            action.tintColor = UIColor(AppPageStyle.tint)
            action.setPreferredSymbolConfiguration(
                UIImage.SymbolConfiguration(pointSize: 28),
                forImageIn: .normal
            )
            let row = UIStackView(arrangedSubviews: [card, action])
            row.spacing = 10
            row.alignment = .center
            addSubview(row)
            card.addSubview(editor)
            card.addSubview(placeholder)
            for child in [row, editor, placeholder] {
                child.translatesAutoresizingMaskIntoConstraints = false
            }
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: leadingAnchor),
                row.trailingAnchor.constraint(equalTo: trailingAnchor),
                row.topAnchor.constraint(equalTo: topAnchor),
                row.bottomAnchor.constraint(equalTo: bottomAnchor),
                card.heightAnchor.constraint(equalTo: row.heightAnchor),
                action.widthAnchor.constraint(equalToConstant: 44),
                action.heightAnchor.constraint(equalToConstant: 44),
                editor.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
                editor.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
                editor.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
                editor.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
                placeholder.leadingAnchor.constraint(equalTo: editor.leadingAnchor),
                placeholder.trailingAnchor.constraint(equalTo: editor.trailingAnchor),
                placeholder.topAnchor.constraint(equalTo: editor.topAnchor),
            ])
        }

        required init?(coder: NSCoder) {
            return nil
        }

        override var intrinsicContentSize: CGSize {
            CGSize(width: UIView.noIntrinsicMetric, height: height(for: max(1, bounds.width)))
        }

        func height(for width: CGFloat) -> CGFloat {
            let textWidth = max(1, width - 44 - 10 - 28)
            let lineHeight = editor.font?.lineHeight ?? 22
            let measured = editor.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude))
                .height
            return ceil(max(44, min(max(lineHeight, measured), lineHeight * 4) + 20))
        }

        func refresh(isAnswering: Bool) {
            let currentText = editor.text ?? ""
            placeholder.isHidden = !currentText.isEmpty
            action.isEnabled = isAnswering || !currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
            action.setImage(
                UIImage(systemName: isAnswering ? "stop.circle.fill" : "arrow.up.circle.fill"),
                for: .normal
            )
            action
                .accessibilityLabel = isAnswering ? String(localized: "Stop response") :
                String(localized: "Send")
            action.accessibilityIdentifier = isAnswering ? "coach.stop" : "coach.send"
            invalidateIntrinsicContentSize()
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CoachComposerField
        weak var view: ComposerView?

        init(_ parent: CoachComposerField) {
            self.parent = parent
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            // A pasted paragraph remains editable. Only the keyboard's single newline sends;
            // an input method must finish composing its marked text first.
            guard text == "\n", textView.markedTextRange == nil else {
                return true
            }
            submit()
            return false
        }

        func textViewDidChange(_ textView: UITextView) {
            if textView.markedTextRange == nil {
                let bounded = String((textView.text ?? "")
                    .prefix(FoundationModelsCoachPrompt.maximumQuestionCharacters))
                if textView.text != bounded {
                    textView.text = bounded
                }
            }
            view?.refresh(isAnswering: parent.isAnswering)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onFocus()
        }

        private func submit() {
            guard !parent.isAnswering, let view, parent.onSubmit(view.editor.text ?? "") else {
                return
            }
            view.editor.text = ""
            view.refresh(isAnswering: false)
            // At accessibility sizes the keyboard leaves very little space for a reply.
            if view.traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
                view.editor.resignFirstResponder()
            }
        }

        @objc func performAction() {
            if parent.isAnswering {
                parent.onStop()
            } else {
                submit()
            }
        }

        @objc func dismissKeyboard() {
            view?.editor.resignFirstResponder()
        }
    }
}
