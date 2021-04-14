

import Cocoa

/// Custom text field delegate, that formats user inputs based on a given currency formatter.
public class CurrencyUITextFieldDelegate: NSObject {

    public var formatter: (CurrencyFormatting & CurrencyAdjusting)!

    public var textUpdated: (() -> Void)?

    /// Text field clears its text when value value is equal to zero.
    public var clearsWhenValueIsZero: Bool = false

    /// A delegate object to receive and potentially handle `UITextFieldDelegate events` that are sent to `CurrencyUITextFieldDelegate`.
    ///
    /// Note: Make sure the implementation of this object does not wrongly interfere with currency formatting.
    ///
    /// By returning `false` on`textField(textField:shouldChangeCharactersIn:replacementString:)` no currency formatting is done.
    public var passthroughDelegate: NSTextViewDelegate? {
        get { return _passthroughDelegate }
        set {
            guard newValue !== self else { return }
            _passthroughDelegate = newValue
        }
    }
    weak private(set) var _passthroughDelegate: NSTextViewDelegate?
    
    public init(formatter: CurrencyFormatter) {
        self.formatter = formatter
    }
}

// MARK: - UITextFieldDelegate

extension CurrencyUITextFieldDelegate: NSTextViewDelegate {
    
    
    

    public func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString : String?) -> Bool {
        let lastSelectedTextRangeOffsetFromEnd = textView.selectedTextRangeOffsetFromEnd

        let string = replacementString ?? ""
        let range = affectedCharRange
        
        defer {
            textView.updateSelectedTextRange(lastOffsetFromEnd: lastSelectedTextRangeOffsetFromEnd)
            textUpdated?()
        }
        
        guard !string.isEmpty else {
            handleDeletion(in: textView, at: range)
            return false
        }
        guard string.hasNumbers else {
            addNegativeSymbolIfNeeded(in: textView, at: range, replacementString: string)
            return false
        }
        
        setFormattedText(in: textView, inputString: string, range: range)

        return false
    }

}


extension CurrencyUITextFieldDelegate {

    private func addNegativeSymbolIfNeeded(in textField: NSTextView, at range: NSRange, replacementString string: String) {
        
        if string == .negativeSymbol && textField.string.isEmpty {
            textField.string = .negativeSymbol
        } else if range.lowerBound == 0 && string == .negativeSymbol &&
            textField.string.contains(String.negativeSymbol) == false {
            
            textField.string = .negativeSymbol + textField.string
        }
    }
    private func handleDeletion(in textField: NSTextView, at range: NSRange) {
        var text = textField.string
        if let textRange = Range(range, in: text) {
            text.removeSubrange(textRange)
        } else {
            text.removeLast()
        }
        
        if text.isEmpty {
            textField.string = text
        } else {
            textField.string = formatter.formattedStringWithAdjustedDecimalSeparator(from: text) ?? ""
        }
    }
    func setFormattedText(in textField: NSTextView, inputString: String, range: NSRange) {
        var updatedText = ""
        
        let text = textField.string
        if text.isEmpty {
            updatedText = formatter.initialText + inputString
        } else if let range = Range(range, in: text) {
            updatedText = text.replacingCharacters(in: range, with: inputString)
        } else {
            updatedText = text.appending(inputString)
        }
        
        if updatedText.numeralFormat().count > formatter.maxDigitsCount {
            updatedText.removeLast()
        }
        
        textField.string = formatter.formattedStringWithAdjustedDecimalSeparator(from: updatedText) ?? ""
    }

}
