// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

struct chars {
    static let BELL = 7;
    static let BACKSPACE = 8;
    static let CARRIAGE_RETURN = 13;
    static let ESCAPE = 27
    static let SQUARE_BRACKET_L = 91
    static let BACKSLASH = 92
    static let SQUARE_BRACKET_R = 93
    static let NEWLINE = 10
}

public struct BufLine {
    public var s: Int;
    public var e: Int;
    
    public init(s: Int, e: Int) {
        self.s = s
        self.e = e
    }
}

public struct Cell {
    public var char: UInt8?;
    public var fgColor: UInt16?;
    public var bgColor: UInt16?;
    public var inverted = false
}

public struct Point {
    public var x: Int
    public var y: Int
    
    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public struct Pen {
    var bgColor: Int = 0;
    var fgColor: Int = 0;
    var inverted = false;
}

public class TTerminal {
    public var WIDTH: UInt16 = 0;
    public var HEIGHT: UInt16 = 0;
    
    public var buf: Data;
    var lines: [BufLine] = []
    var currentLineIndex: Int?

    public var pen = Pen()
    public var cursor = Point(x: 0, y: 0)
    
    var cx = 0;
    var cy = 0;
    
    var scrollTop = 0;
    var scrollBottom = 0;
    
    public var cells: Array<Cell> = []
    
    private var parser: Parser!;

    public init(buffer: Data) {
        buf = buffer;
        parser = Parser(terminal: self)
    }
    
    public func resize(width: UInt16, height: UInt16) {
        WIDTH = width
        HEIGHT = height
        scrollBottom = Int(height - 1)
        cells = Array<Cell>(repeating: Cell(), count: Int(width * height));
        
        // TODO: redraw
        cursor.x = 0
        cursor.y = 0
        cx = 0
        cy = 0
        
        // TODO: shouldn't parse the entire buffer, maybe the last so many lines?
        parser.parse(newData: buf)
    }
    
    public func parseIncomingLines(_ incoming: Data) {
        if incoming.count == 0 { return }
        
        /*
         current line is not ended -> append
         current line is ended -> create new
         */
        
        if currentLineIndex == nil {
            if let ll = lines.last {
                lines.append(BufLine(s: ll.e + 1, e: ll.e))
            } else {
                lines.append(BufLine(s: 0, e: -1))
            }
            currentLineIndex = lines.count - 1
        }
        
        for (i, c) in incoming.enumerated() {
            let b = lines.endIndex - 1
            lines[b].e += 1
            
            if c == Character("\n").asciiValue {
                if i == incoming.endIndex - 1 {
                    // no more data, stop creating lines
                    currentLineIndex = nil
                    break
                }
                
                lines.append(BufLine(s: lines[b].s + 1, e: lines[b].e))
            }
        }
        
        self.buf.append(incoming)
        self.parser.parse(newData: incoming)
    }

    func parseLines(lines: Array<BufLine>) {
        parser.parseLines(lines: lines);
    }
    
    public func draw() {
        // TODO
        
        let nc = NotificationCenter.default
        nc.post(name: Notification.Name("TerminalDataUpdate"), object: nil)
    }
}

class Parser {
    var t: TTerminal;
    
    init(terminal: TTerminal) {
        t = terminal;
    }
    
    
    func parse(newData: Data) {
        var idx = 0;
        while idx < newData.count  {
            let c = newData[idx]
            
            // loop until either escape code or new line
            if c == chars.ESCAPE {
                idx += 1
                parseEscapeCode(idx: &idx)
            } else if c == chars.BELL  {
                // do nothing?
            } else if c == chars.BACKSPACE  {
                idx += 1
                t.cursor.x -= 1
                t.cx -= 1
            } else if c == chars.CARRIAGE_RETURN {
                idx += 1
                t.cx = 0;
                t.cursor.x = 0;
            } else if c == chars.NEWLINE {
                idx += 1
                t.cx = 0
                incY()
                
                t.cursor.x = t.cx
                t.cursor.y = t.cy
            } else {
                // normal char, print
                // print(Character(UnicodeScalar(c)))
                let yOffset = t.cy * Int(t.WIDTH)
                idx += 1;
                t.cells[yOffset + t.cx].char = c
                incX()
            }
        }
    }

    func parseLines(lines: Array<BufLine>) {
        for line in lines {
            var idx: Int = line.s;
            
            while idx <= line.e {
                // read until escape char
                let cy = t.cy * Int(t.WIDTH)
                while (idx <= line.e && t.buf[idx] != chars.ESCAPE) {
                    print(Character(UnicodeScalar(t.buf[idx])))
                    t.cells[cy + t.cx].char = t.buf[idx]
                    incX()
                    idx += 1;
                }
                
                if idx >= line.e {
                    break;
                }

                if (t.buf[idx] == chars.ESCAPE) {
                    idx += 1;
                    parseEscapeCode(idx: &idx);
                }
            }
            
            // TODO: maybe this needs to check if there's a new line?
            t.cy += 1;
            t.cx = 0;
        }
    }
    
    func incX() {
        t.cx += 1;
        t.cursor.x += 1
        if t.cx == t.WIDTH {
            t.cx = 0;
            incY()
            
            t.cursor.x = 0
            t.cursor.y = t.cy
        }
    }
    
    func incY() {
        let shouldScroll = t.cy == t.scrollBottom

        if shouldScroll == false && t.cy + 1 < t.HEIGHT {
            t.cy += 1;
        }
        
        if shouldScroll {
            let WIDTH = Int(t.WIDTH);
            let HEIGHT = Int(t.HEIGHT);

            // we're at the bottom of the grid, so don't "move down"
            // everything will shift up instead
            let a = t.cells[0 ..< (t.scrollTop * WIDTH)] // everything up until the scroll region, should be 0 for normal operation
            let b = t.cells[((t.scrollTop + 1) * WIDTH) ..< ((t.scrollBottom + 1) * WIDTH)] // scroll region start + 1 (as we're 'scrolling', so skip first line)
            let c = t.cells[((t.scrollTop) * WIDTH) ..< ((t.scrollTop + 1) * WIDTH)] // first line of scroll region
            let d = t.scrollBottom == HEIGHT - 1
                ? []
            : t.cells[((t.scrollBottom + 1) * WIDTH)..<HEIGHT*WIDTH] // the rest

            t.cells = Array(a + b + c + d)
            clearRow(y: t.cy)
        }
    }

    func clearCell(cell: inout Cell) {
        cell.char = nil;
        cell.bgColor = 40
        cell.fgColor = 37
        cell.inverted = false
    }
    
    func clearRow(y: Int) {
        let WIDTH = Int(t.WIDTH)
        
        for i in (WIDTH*y)..<(WIDTH*(y+1)) {
            self.clearCell(cell: &t.cells[i])
        }
    }

    func parseEscapeCode(idx: inout Int) {
        if (t.buf[idx] == chars.SQUARE_BRACKET_L) {
            idx += 1
            parseControlCode(idx: &idx)
        } else {
            print("Unknown escape code: \(Character(UnicodeScalar(t.buf[idx])))")
            idx += 1
        }
    }
    
    func parseControlCode(idx: inout Int) {
        var questionMark = false;
        if (t.buf[idx] == Character("?").asciiValue) {
            idx += 1
            questionMark = true;
        }
        
        let number = readNumber(idx: &idx);
        if (t.buf[idx] == Character("m").asciiValue) {
            idx += 1;
            t.pen.fgColor = number;
        } else {
            print("Unknown control code: \(Character(UnicodeScalar(t.buf[idx])))")
            idx += 1;
        }
    }
    
    func readNumber(idx: inout Int) -> Int {
        var numbers = [Int](repeating: 0, count: 10)
        var count = 0;
        
        while (t.buf[idx] >= Character("0").asciiValue! && t.buf[idx] <= Character("9").asciiValue!) {
            numbers[count] = Int(t.buf[idx]) - 48;
            count += 1;
            
            idx += 1;
        }
        
        if (count == 0) {
            return 0;
        }
        
        var curr = 0;
        var iter = count - 1;
        for i in 0..<count {
            curr += numbers[i] * Int(pow(10.0, Double(iter)));
            iter -= 1;
        }
        
        return curr;
    };
};
