import SwiftUI
import UIKit

struct EndAlignedNumberField: UIViewRepresentable {
    let value: String
    let allowsDecimal: Bool
    let onValueChange: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)
        textField.text = value
        textField.textAlignment = .right
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.font = .monospacedDigitSystemFont(ofSize: 24, weight: .semibold)
        textField.textColor = UIColor(AppPalette.ink)
        textField.keyboardType = allowsDecimal ? .decimalPad : .numberPad
        textField.adjustsFontSizeToFitWidth = true
        textField.minimumFontSize = 18
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self
        if !textField.isFirstResponder, textField.text != value {
            textField.text = value
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EndAlignedNumberField

        init(parent: EndAlignedNumberField) {
            self.parent = parent
        }

        @objc func editingChanged(_ textField: UITextField) {
            parent.onValueChange(textField.text ?? "")
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                let end = textField.endOfDocument
                textField.selectedTextRange = textField.textRange(from: end, to: end)
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            textField.text = parent.value
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            guard let current = textField.text,
                  let swiftRange = Range(range, in: current) else { return false }
            let candidate = current.replacingCharacters(in: swiftRange, with: string)
            guard candidate.count <= 6 else { return false }
            if parent.allowsDecimal {
                return candidate.allSatisfy { $0.isNumber || $0 == "." }
                    && candidate.filter { $0 == "." }.count <= 1
            }
            return candidate.allSatisfy(\.isNumber)
        }
    }
}
