@testable import term
import Testing

import Foundation

class ControlSequenceParserTests {
    @Test func testingBasicEscapeCodes() async throws {
        let p = ControlSequenceParser()
        _ = p.parse(b("\u{1b}[32m"), index: 0)
        #expect(p.numbers[0] == 32)
        #expect(p.csi == .SGR)
        
        _ = p.parse(b("Hello\u{1b}[2;3H"), index: 5)
        #expect(p.numbers[0] == 2)
        #expect(p.numbers[1] == 3)
        #expect(p.csi == .CUP)
    }
    
    @Test func testingParsingSplitEscapeCode() async throws {
        let p = ControlSequenceParser()
        _ = p.parse(b("\u{1b}[4"), index: 0)
        _ = p.parse(b("5mHelloWorld"), index: 0)
        #expect(p.numbers[0] == 45)
        #expect(p.csi == .SGR)
    }

    func b(_ input: String) -> Data {
        return input.data(using: .utf8)!
    }
}
