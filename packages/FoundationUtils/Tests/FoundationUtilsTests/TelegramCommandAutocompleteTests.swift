import XCTest
@testable import FoundationUtils

final class TelegramCommandAutocompleteTests: XCTestCase {
    func testKeepsAutocompleteOpenForAlphanumericCommandQuery() {
        let text = "/codex"
        
        let range = TelegramCommandAutocomplete.queryRange(in: text, cursorUTF16Offset: text.utf16.count)
        
        XCTAssertNotNil(range)
        XCTAssertEqual(String(text[range!]), "codex")
    }
    
    func testKeepsAutocompleteOpenForUnderscoreInCommandQuery() {
        let text = "/codex_compact"
        
        let range = TelegramCommandAutocomplete.queryRange(in: text, cursorUTF16Offset: text.utf16.count)
        
        XCTAssertNotNil(range)
        XCTAssertEqual(String(text[range!]), "codex_compact")
    }
    
    func testRejectsInvalidCommandCharacters() {
        let text = "/codex-compact"
        
        let range = TelegramCommandAutocomplete.queryRange(in: text, cursorUTF16Offset: text.utf16.count)
        
        XCTAssertNil(range)
    }
}
