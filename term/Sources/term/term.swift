// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

struct chars {
    static let BELL = 7;
    static let BACKSPACE = 8;
    static let NEWLINE = 10
    static let CARRIAGE_RETURN = 13;
    static let ESCAPE = 27
    static let SEMI_COLON = 59
    static let EQUALS = 61
    static let GREATER_THAN = 62
    static let QUESTION = 63
    static let SQUARE_BRACKET_L = 91
    static let BACKSLASH = 92
    static let SQUARE_BRACKET_R = 93
    
    static let A = 65
    static let B = 66
    static let C = 67
    static let D = 68
    static let E = 69
    static let F = 70
    static let G = 71
    static let H = 72
    static let I = 73
    static let J = 74
    static let K = 75
    static let L = 76
    static let M = 77
    static let N = 78
    static let O = 79
    static let P = 80

    static let a = 97
    static let b = 98
    static let c = 99
    static let d = 100
    static let e = 101
    static let f = 102
    static let g = 103
    static let h = 104
    static let i = 105
    static let j = 106
    static let k = 107
    static let l = 108
    static let m = 109
    static let n = 110
    static let o = 111
    static let p = 112
    static let q = 113
    static let r = 114

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
    public var fgColor: Int?;
    public var bgColor: Int?;
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
    var bgColor = 0;
    var fgColor = 0;
    var inverted = false;
}

public class TTerminal {
    public var WIDTH = 0;
    public var HEIGHT = 0;
    
    public var buf: Data;
    var lines: [BufLine] = []
    var currentLineIndex: Int?

    public var pen = Pen()
    public var cursor = Point(x: 0, y: 0)
    
    var scrollTop = 0;
    var scrollBottom = 0;
    
    public var cells: Array<Cell> = []
    
    var alternateCells: Array<Cell>?
    var alternateCursor: Point?
    var alternatePen: Pen?

    private var parser: Parser!;

    public init(buffer: Data) {
        buf = buffer;
        parser = Parser(terminal: self)
    }
    
    public func resize(width: Int, height: Int) {
        WIDTH = width
        HEIGHT = height
        scrollBottom = height - 1
        cells = Array<Cell>(repeating: Cell(), count: width * height);
        
        // TODO: redraw
        cursor.x = 0
        cursor.y = 0
        
        // TODO: shouldn't parse the entire buffer, maybe the last so many lines?
        parser.parse(newData: buf)
    }
    
    public func parseIncomingLines(_ incoming: Data) {
        if incoming.count == 0 { return }
        
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
            idx += 1

            // loop until either escape code or new line
            if c == chars.ESCAPE {
                parseEscapeCode(newData, idx: &idx)
            } else if c == chars.BELL  {
                // do nothing?
            } else if c == chars.BACKSPACE  {
                t.cursor.x -= 1
            } else if c == chars.CARRIAGE_RETURN {
                t.cursor.x = 0;
            } else if c == chars.NEWLINE {
                t.cursor.x = 0
                incY()
            } else {
                // normal char, print
                let yOffset = t.cursor.y * Int(t.WIDTH)
                let ci = yOffset + t.cursor.x
                t.cells[ci].char = c
                t.cells[ci].fgColor = t.pen.fgColor
                t.cells[ci].bgColor = t.pen.bgColor
                incX()
            }
        }
    }
    
    func incX() {
        t.cursor.x += 1
        if t.cursor.x == t.WIDTH {
            t.cursor.x = 0;
            incY()
        }
    }
    
    func incY() {
        let shouldScroll = t.cursor.y == t.scrollBottom

        if shouldScroll == false && t.cursor.y + 1 < t.HEIGHT {
            t.cursor.y += 1;
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
            clearRow(y: t.cursor.y)
        }
    }

    func clearCell(cell: inout Cell) {
        cell.char = nil;
        cell.bgColor = 40
        cell.fgColor = 37
        cell.inverted = false
    }
    
    func clearRow(y: Int) {
        let WIDTH = t.WIDTH
        
        for i in (WIDTH*y)..<(WIDTH*(y+1)) {
            self.clearCell(cell: &t.cells[i])
        }
    }

    func parseEscapeCode(_ input: Data, idx: inout Int) {
        if idx == input.count {
            print("CANNOT PARSE ESCAPE CODE")
            return
        }
        
        let c = input[idx]
        idx += 1
        
        if c == chars.SQUARE_BRACKET_L {
            parseControlCode(input, idx: &idx)
        } else if c == chars.SQUARE_BRACKET_R {
            parseOperatingSystemControl(input, idx: &idx)
        } else if c == chars.EQUALS {
            print("Application Keypad (DECPAM)")
        } else {
            print("Unknown escape code: \(Character(UnicodeScalar(c)))")
        }
    }
    
    func parseControlCode(_ input: Data, idx: inout Int) {
        var questionMark = false;
        if input[idx] == chars.QUESTION {
            idx += 1
            questionMark = true;
        }
        
        if input[idx] == chars.GREATER_THAN {
            // unsure
            idx += 1
            print("CSI >")
        }
        
        var numbers = [readNumber(input, idx: &idx), 0, 0, 0]
        var numCount = 1
        
        while input[idx] == chars.SEMI_COLON {
            idx += 1
            numbers[numCount] = readNumber(input, idx: &idx)
            numCount += 1
        }
        
        if questionMark {
            if input[idx] == chars.h {
                idx += 1
                switch numbers[0] {
                case 1049:
                    t.alternateCells = t.cells
                    t.alternatePen = t.pen
                    t.alternateCursor = t.cursor
                    
                    t.cells = [Cell](repeating: Cell(), count: t.WIDTH * t.HEIGHT);
                    t.pen = Pen()
                    t.pen.fgColor = 37
                    t.pen.bgColor = 40
                    t.cursor = Point(x: 0, y: 0)
                case 12:
                    print("Start Blinking Cursor (att610)")
                case 25:
                    print("TODO: Shows the cursor")
                default:
                    print("Unknown CSI number for ? h: \(numbers[0])")
                }
            } else if input[idx] == chars.l {
                idx += 1
                switch numbers[0] {
                case 1049:
                    guard let pen = t.alternatePen, let cells = t.alternateCells, let cursor = t.alternateCursor else {
                        print("Invalid alternative cells data")
                        break
                    }
                    t.cells = cells
                    t.pen = pen
                    t.cursor = cursor
                    
                    t.alternateCells = nil
                    t.alternatePen = nil
                    t.alternateCursor = nil
                case 12:
                    print("Stop Blinking Cursor (att610)")
                case 25:
                    print("TODO: Hide the cursor")
                default:
                    print("Unknown CSI number for ? h: \(numbers[0])")
                }
            } else {
                print("Unknown CSI from question mark: \(Character(UnicodeScalar(input[idx])))")
                idx += 1
            }
        
            return;
        }
        
        if input[idx] == chars.m {
            idx += 1;
            for ni in 0..<numCount {
                let number = numbers[ni]
                switch number {
                case 30...37:
                    print("setting FG colour to \(number)")
                    t.pen.fgColor = number
                case 39:
                    print("setting FG colour to default: 37")
                    t.pen.fgColor = 37 /* default: white */
                case 40...47:
                    print("setting BG colour to \(number)")
                    t.pen.bgColor = number
                case 49:
                    print("setting BG colour to default: 40")
                    t.pen.bgColor = 40 /* default: black */
                default:
                    print("Unknown CSI number for m: \(number)")
                }
            }
        } else if input[idx] == chars.r {
            idx += 1
            t.scrollTop = numbers[0] - 1
            t.scrollBottom = numbers[1] - 1
            print("updating scroll region: \(numbers)")
        } else if input[idx] == chars.C {
            idx += 1
            print("moving cursor \(numbers[0]) forward")
            t.cursor.x += numbers[0]
        } else if input[idx] == chars.H {
            idx += 1
            let n = numbers[0] == 0 ? 1 : numbers[0]
            let m = numbers[1] == 0 ? 1 : numbers[1]
            t.cursor.y = n - 1
            t.cursor.x = m - 1
            print("moving cursor to \(n):\(m)")
        } else if input[idx] == chars.J {
            idx += 1
            switch numbers[0] {
            case 0:
                print("0J")
                for i in t.cursor.x ..< t.WIDTH { clearCell(cell: &t.cells[i] ) }
            case 1:
                print("1J")
                for i in 0 ... t.cursor.x { clearCell(cell: &t.cells[i] ) }
            case 2:
                print("2J")
                for i in 0 ..< t.HEIGHT { clearRow(y: i) }
            default:
                print("Unknown CSI number for J: \(numbers[0])")
            }
        } else if (input[idx] == chars.K) {
            idx += 1
            let n = numbers[0]
            if n == 0 {
                print("[\(n)K -- y: \(t.cursor.y) | x: \(t.cursor.x) to WIDTH")
                // If n is 0 (or missing), clear from cursor to the end of the line.
                // for c in x..<WIDTH { self.cells[c + (ay * WIDTH)].char = nil }
                for c in t.cursor.x..<t.WIDTH { clearCell(cell: &t.cells[c + (t.cursor.y * t.WIDTH)]) }
            } else if n == 1 {
                print("[\(n)K -- 0 to \(t.cursor.x)")
                // If n is 1, clear from cursor to beginning of the line.
                for c in 0..<idx { clearCell(cell: &t.cells[c + (t.cursor.y * t.WIDTH)]) }
            } else {
                print("[\(n)K -- CLEAR")
                // If n is 2, clear entire line. Cursor position does not change.
                for c in 0..<t.WIDTH { clearCell(cell: &t.cells[c + (t.cursor.y * t.WIDTH)]) }
            }
            
            
        } else if input[idx] == chars.L {
            idx += 1;
            let n = numbers[0] == 0 ? 1 : numbers[0]
            
            for _ in 0..<n {
                insertLine()
            }
        } else if input[idx] == chars.M {
            idx += 1;
            let n = numbers[0] == 0 ? 1 : numbers[0]
            
            for _ in 0..<n {
                deleteLine()
            }
        } else if (input[idx] == chars.P) {
            idx += 1
            // delete chars
            print("Deleting \(numbers[0]) chars")
            let yOffset = t.cursor.y * t.WIDTH
            for i in t.cursor.x..<t.WIDTH {
                t.cells[yOffset + i] = t.cells[yOffset + i + numbers[0]]
            }
        } else {
            print("Unknown control code: \(Character(UnicodeScalar(input[idx]))) : \(numbers)")
            idx += 1;
        }
    }
    
    func parseOperatingSystemControl(_ input: Data, idx: inout Int) {
        var numbers = [readNumber(input, idx: &idx), 0, 0, 0]
        var numCount = 1
        
        while input[idx] == chars.SEMI_COLON {
            idx += 1
            numbers[numCount] = readNumber(input, idx: &idx)
            numCount += 1
        }
        
        var questionMark = false;
        if input[idx] == chars.QUESTION {
            idx += 1
            questionMark = true;
        }
        
        if questionMark {
            print("todo: send back appropriate colour")
        }

        if input[idx] == chars.BELL {
            idx += 1;
            print("OSC ] \(numbers)")
        } else {
            print("unknown osc \(UnicodeScalar(input[idx]))")
        }
    }

    
    func readNumber(_ input: Data, idx: inout Int) -> Int {
        var numbers = [Int](repeating: 0, count: 10)
        var count = 0;
        
        let zero = 48
        let nine = 57
        while (idx < input.count && input[idx] >= zero && input[idx] <= nine) {
            numbers[count] = Int(input[idx]) - zero
            count += 1
            idx += 1
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
    }
    
    func deleteLine() {
        // get 0 to < y
        let a = t.cells[0 ..< (t.cursor.y * t.WIDTH)]
        
        // get the rest of the scroll region (-1)
        let b = t.cells[((t.cursor.y + 1) * t.WIDTH) ..< ((t.scrollBottom + 1) * t.WIDTH)]
        
        // get the current y line (this will be cleared)
        let c = t.cells[(t.cursor.y * t.WIDTH) ..< ((t.cursor.y + 1) * t.WIDTH)]
        
        let d = t.scrollBottom == t.HEIGHT - 1
        ? []
        : t.cells[((t.scrollBottom + 1) * t.WIDTH)..<t.HEIGHT*t.WIDTH] // the rest
        
        t.cells = Array(a + b + c + d)
        clearRow(y: t.scrollBottom)
    }
    
    func insertLine() {
        // get 0 to < y
        let a = t.cells[0 ..< (t.cursor.y * t.WIDTH)]
        
        // get last line of scroll region, this is the "new" line
        let b = t.cells[(t.scrollBottom * t.WIDTH) ..< ((t.scrollBottom + 1) * t.WIDTH)]
        
        // get the rest of the scroll region (-1)
        let c = t.cells[((t.cursor.y) * t.WIDTH) ..< ((t.scrollBottom) * t.WIDTH)]
        
        let d = t.scrollBottom == t.HEIGHT - 1
        ? []
        : t.cells[((t.scrollBottom + 1) * t.WIDTH)..<t.HEIGHT*t.WIDTH] // the rest
        
        
        t.cells = Array(a + b + c + d)
        clearRow(y: t.cursor.y)
    }
    
};
