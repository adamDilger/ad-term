@testable import term
import Testing

import Foundation

@Test func example() async throws {
    var buf = Data()
    let t = TTerminal(buffer: buf)
    t.resize(width: 80, height: 80)

    buf.append("Hello \u{1b}[33mWorld".data(using: .utf8)!)

    #expect(t.pen.fgColor == 0)
    t.parseIncomingLines(buf)

    var i = 0
    for c in "Hello World" {
        #expect(t.cells[i].char == c.asciiValue)
        i += 1
    }

    #expect(t.pen.fgColor == 33)
}

@Test func multiline() async throws {
    let buf = "Hello\nWorld".data(using: .ascii)!
    let t = TTerminal(buffer: buf)
    t.resize(width: 80, height: 80)

    t.parseIncomingLines(buf)

    var i = 0
    for c in "Hello" {
        #expect(t.cells[i].char == c.asciiValue)
        i += 1
    }

    i = 0
    for c in "World" {
        #expect(t.cells[80 + i].char == c.asciiValue)
        i += 1
    }
}

@Test func wrapline() async throws {
    let buf = "HelloWorld".data(using: .ascii)!
    let t = TTerminal(buffer: buf)
    t.resize(width: 5, height: 80)
    
    t.parseIncomingLines(buf)
    
    var i = 0
    for c in "Hello" {
        #expect(t.cells[i].char == c.asciiValue)
        i += 1
    }
    
    i = 0
    for c in "World" {
        #expect(t.cells[5 + i].char == c.asciiValue)
        i += 1
    }
}
