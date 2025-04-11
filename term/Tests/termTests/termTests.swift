import Testing
@testable import term

import Foundation

@Test func example() async throws {
    let buf = "Hello \u{1B}[38mWorld".data(using: .ascii)!
    let p = Parser(buffer: buf)
    p.resize(width: 80, height: 80)
    
    #expect(p.fgColor == 0)
    p.parseLines(lines: [BufLine(s: 0, e: buf.count - 1)])
    
    var i = 0;
    for c in "Hello World" {
        #expect(p.cells[i].char == c.asciiValue)
        i += 1
    }
    
    #expect(p.fgColor == 38)
}

@Test func multiline() async throws {
    let buf = "Hello\nWorld".data(using: .ascii)!
    let p = Parser(buffer: buf)
    p.resize(width: 80, height: 80)
    
    let lines = linesFromString("Hello\nWorld");
    p.parseLines(lines: lines);
    
    var i = 0;
    for c in "Hello" {
        #expect(p.cells[i].char == c.asciiValue)
        i += 1
    }
    
    i = 0;
    for c in "World" {
        #expect(p.cells[80 + i].char == c.asciiValue)
        i += 1
    }
}

@Test func wrapline() async throws {
    let buf = "HelloWorld".data(using: .ascii)!
    let p = Parser(buffer: buf)
    p.resize(width: 5, height: 80)
    
    let lines = linesFromString("HelloWorld");
    p.parseLines(lines: lines);
    
    var i = 0;
    for c in "Hello" {
        #expect(p.cells[i].char == c.asciiValue)
        i += 1
    }
    
    i = 0;
    for c in "World" {
        #expect(p.cells[5 + i].char == c.asciiValue)
        i += 1
    }
}

func linesFromString(_ input: String) -> [BufLine] {
    var lines: [BufLine] = [];
    
    var s = 0;
    var e = 0;
    
    for c in input {
        if c == Character("\n") {
            lines.append(BufLine(s: s, e: e))
            e += 1
            s = e
        } else {
            e += 1;
        }
    }
    
    if s != e {
        lines.append(BufLine(s: s, e: e - 1))
    }
    
    return lines
}
