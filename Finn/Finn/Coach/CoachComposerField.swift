import SwiftUI
import UIKit

/// A native multiline input with an explicit Send action. Observing SwiftUI's draft binding
/// cannot distinguish Return from several coalesced edits or an autocorrection.
struct CoachComposerField: UIViewRepresentable {
    @Binding var text: String
    var resetID: UUID
    var onSubmit: () -> Void
    var onFocus: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.text = text
        view.backgroundColor = .clear
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = .label
        view.tintColor = UIColor(AppPageStyle.tint)
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.returnKeyType = .send
        view.enablesReturnKeyAutomatically = true
        view.accessibilityIdentifier = "coach.field"
        view.accessibilityLabel = String(localized: "Ask about your sets")
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.tintColor = UIColor(AppPageStyle.tint)
        let done = UIBarButtonItem(title: String(localized: "Done"), style: .prominent,
                                   target: context.coordinator, action: #selector(Coordinator.dismissKeyboard))
        done.accessibilityIdentifier = "coach.dismissKeyboard"
        toolbar.items = [.flexibleSpace(), done]
        view.inputAccessoryView = toolbar
        context.coordinator.textView = view
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.isApplyingModelText = true
        defer { context.coordinator.isApplyingModelText = false }
        // Native edits already live in the editor. Replaying an older SwiftUI snapshot can
        // overwrite a newer keystroke. Only a deliberate composer reset writes text back.
        if context.coordinator.resetID != resetID {
            context.coordinator.resetID = resetID
            view.text = text
            view.invalidateIntrinsicContentSize()
        }
    }

    static func dismantleUIView(_ view: UITextView, coordinator: Coordinator) {
        view.delegate = nil
        view.resignFirstResponder()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let lineHeight = uiView.font?.lineHeight ?? UIFont.preferredFont(forTextStyle: .body).lineHeight
        let measured = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: min(max(lineHeight, measured.height), lineHeight * 4))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CoachComposerField
        weak var textView: UITextView?
        var isApplyingModelText = false
        var resetID: UUID

        init(_ parent: CoachComposerField) {
            self.parent = parent
            resetID = parent.resetID
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange,
                      replacementText text: String) -> Bool {
            // A pasted paragraph arrives as one replacement and stays editable. Send is a
            // single newline; marked text must finish composing before it can be submitted.
            guard text == "\n", textView.markedTextRange == nil else { return true }
            parent.onSubmit()
            return false
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingModelText else { return }
            let bounded = String((textView.text ?? "").prefix(FoundationModelsCoachPrompt.maximumQuestionCharacters))
            if textView.text != bounded { textView.text = bounded }
            parent.text = bounded
            textView.invalidateIntrinsicContentSize()
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            // UIKit owns focus. Mirroring it back through updateUIView can resign the editor
            // during a keyboard transition and lose an in-flight keystroke.
            parent.onFocus()
        }

        @objc func dismissKeyboard() {
            textView?.resignFirstResponder()
        }
    }
}
