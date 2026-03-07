import Foundation

public enum TelegramCommandAutocomplete {
    public static func queryRange(in text: String, cursorUTF16Offset: Int) -> Range<String.Index>? {
        let cursorUTF16Offset = min(max(0, cursorUTF16Offset), text.utf16.count)
        let cursorUTF16Index = text.utf16.index(text.utf16.startIndex, offsetBy: cursorUTF16Offset)
        guard let cursorIndex = cursorUTF16Index.samePosition(in: text) else {
            return nil
        }
        guard text.startIndex < cursorIndex, text.first == "/" else {
            return nil
        }
        if cursorIndex < text.endIndex, !text[cursorIndex].isWhitespace {
            return nil
        }
        let commandStartIndex = text.index(after: text.startIndex)
        for character in text[commandStartIndex ..< cursorIndex] {
            guard isValidCommandCharacter(character) else {
                return nil
            }
        }
        return commandStartIndex ..< cursorIndex
    }
    
    private static func isValidCommandCharacter(_ character: Character) -> Bool {
        if character == "_" {
            return true
        }
        guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else {
            return false
        }
        return CharacterSet.alphanumerics.contains(scalar)
    }
}
