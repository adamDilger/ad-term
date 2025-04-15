// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

enum chars {
    static let BELL = 7
    static let BACKSPACE = 8
    static let NEWLINE = 10
    static let CARRIAGE_RETURN = 13
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
    static let s = 115
    static let t = 116
    static let u = 117
    static let v = 118
    static let w = 119
    static let x = 120
    static let y = 121
    static let z = 122
    }

public struct BufLine {
    public var s: Int
    public var e: Int

    public init(s: Int, e: Int) {
        self.s = s
        self.e = e
    }
}

public struct Cell {
    public var char: UInt8?
    public var fgColor: Int?
    public var bgColor: Int?
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
    var bgColor = 0
    var fgColor = 0
    var inverted = false
}

let DEFAULT_FG_COLOR = 37
let DEFAULT_BG_COLOR = 40

public class TTerminal {
    public var WIDTH = 0
    public var HEIGHT = 0
    
    public var buf: Data
    var lines: [BufLine] = []
    var currentLineIndex: Int?
    
    public var pen = Pen()
    public var cursor = Point(x: 0, y: 0)
    
    var scrollTop = 0
    var scrollBottom = 0
    
    public var cells: [Cell] = []
    
    var alternateCells: [Cell]?
    var alternateCursor: Point?
    var alternatePen: Pen?
    
    private var parser: Parser!
    private var report: (String) -> ()
    
    public init(buffer: Data, reporter: @escaping (String) -> ()) {
        buf = buffer
        report = reporter
        parser = Parser(terminal: self)
    }
    
    public func resize(width: Int, height: Int) {
        WIDTH = width
        HEIGHT = height
        scrollBottom = height - 1
        cells = [Cell](repeating: Cell(), count: width * height)
        
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
        
        buf.append(incoming)
        parser.parse(newData: incoming)
    }
    
    func replyToShell(_ s: String) {
        self.report(s)
    }
}

class Parser {
    var t: TTerminal
    var controlParser = ControlSequenceParser()

    init(terminal: TTerminal) {
        t = terminal
    }

    func parse(newData: Data) {
        var idx = 0
        while idx < newData.count {
            if controlParser.isParsing {
                // we're half way through, keep going!
                idx = controlParser.parse(newData, index: idx)
                if controlParser.isParsing == false { parseEscapeCode() }
                continue
            }
            
            let c = newData[idx]
            idx += 1

            // loop until either escape code or new line
            if c == chars.ESCAPE {
                idx -= 1 // TODO:
                idx = controlParser.parse(newData, index: idx)
                
                if controlParser.isParsing == false { parseEscapeCode() }
            } else if c == chars.BELL {
                // do nothing?
            } else if c == chars.BACKSPACE {
                t.cursor.x -= 1
            } else if c == chars.CARRIAGE_RETURN {
                t.cursor.x = 0
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
                t.cells[ci].inverted = t.pen.inverted
                incX()
            }
        }
    }

    func incX() {
        t.cursor.x += 1
        if t.cursor.x == t.WIDTH {
            t.cursor.x = 0
            incY()
        }
    }

    func incY() {
        let shouldScroll = t.cursor.y == t.scrollBottom

        if shouldScroll == false, t.cursor.y + 1 < t.HEIGHT {
            t.cursor.y += 1
        }

        if shouldScroll {
            let WIDTH = Int(t.WIDTH)
            let HEIGHT = Int(t.HEIGHT)

            // we're at the bottom of the grid, so don't "move down"
            // everything will shift up instead
            let a = t.cells[0 ..< (t.scrollTop * WIDTH)] // everything up until the scroll region, should be 0 for normal operation
            let b = t.cells[((t.scrollTop + 1) * WIDTH) ..< ((t.scrollBottom + 1) * WIDTH)] // scroll region start + 1 (as we're 'scrolling', so skip first line)
            let c = t.cells[((t.scrollTop) * WIDTH) ..< ((t.scrollTop + 1) * WIDTH)] // first line of scroll region
            let d = t.scrollBottom == HEIGHT - 1
                ? []
                : t.cells[((t.scrollBottom + 1) * WIDTH) ..< HEIGHT * WIDTH] // the rest

            t.cells = Array(a + b + c + d)
            clearRow(y: t.cursor.y)
        }
    }

    func clearCell(cell: inout Cell) {
        cell.char = nil
        cell.bgColor = t.pen.bgColor
        cell.fgColor = t.pen.fgColor
        cell.inverted = false
    }

    func clearRow(y: Int) {
        let WIDTH = t.WIDTH

        for i in (WIDTH * y) ..< (WIDTH * (y + 1)) {
            clearCell(cell: &t.cells[i])
        }
    }

    func parseEscapeCode() {
        let c1 = controlParser.c1
        
        switch c1 {
        case .CSI: parseControlCode()
        case .OSC: parseOperatingSystemControl()
        default: print("UNKNOWN")
        }
    }

    func parseControlCode() {
        let questionMark = controlParser.questionMark
        let numbers = controlParser.numbers
        let csi = controlParser.csi

        if questionMark {
            if csi == .DECSET {
                switch numbers[0] {
                case 1049:
                    t.alternateCells = t.cells
                    t.alternatePen = t.pen
                    t.alternateCursor = t.cursor

                    t.cells = [Cell](repeating: Cell(), count: t.WIDTH * t.HEIGHT)
                    t.pen = Pen()
                    t.pen.fgColor = DEFAULT_FG_COLOR
                    t.pen.bgColor = DEFAULT_BG_COLOR
                    t.cursor = Point(x: 0, y: 0)
                case 12:
                    print("Start Blinking Cursor (att610)")
                case 25:
                    print("TODO: Shows the cursor")
                default:
                    print("Unknown DECSET number for ? h: \(numbers[0])")
                }
            } else if csi == .DECRST {
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
                    print("Unknown DECRST number for ? h: \(numbers[0])")
                }
            }

            return
        }

        if csi == .SGR {
            for ni in 0 ..< controlParser.numCount {
                let number = numbers[ni]
                switch number {
                case 0:
                    print("RESETTING ALL SGR \(number)")
                    t.pen.fgColor = DEFAULT_FG_COLOR
                    t.pen.bgColor = DEFAULT_BG_COLOR
                    t.pen.inverted = false
                case 7:
                    print("setting inverted pen")
                    t.pen.inverted = true
                case 27:
                    print("setting inverted pen to false")
                    t.pen.inverted = false
                case 30 ... 37:
                    print("setting FG colour to \(number)")
                    t.pen.fgColor = number
                case 39:
                    print("setting FG colour to default: 37")
                    t.pen.fgColor = DEFAULT_FG_COLOR
                case 40 ... 47:
                    print("setting BG colour to \(number)")
                    t.pen.bgColor = number
                case 49:
                    print("setting BG colour to default: 40")
                    t.pen.bgColor = DEFAULT_BG_COLOR
                default:
                    print("Unknown CSI number for m: \(number)")
                }
            }
        } else if csi == .DECSTBM {
            t.scrollTop = numbers[0] - 1
            t.scrollBottom = numbers[1] - 1
            print("updating scroll region: \(numbers)")
        } else if csi == .CUF {
            print("moving cursor \(numbers[0]) forward")
            t.cursor.x += numbers[0]
        } else if csi == .CUP {
            let n = numbers[0] == 0 ? 1 : numbers[0]
            let m = numbers[1] == 0 ? 1 : numbers[1]
            t.cursor.y = n - 1
            t.cursor.x = m - 1
            print("moving cursor to \(n):\(m)")
        } else if csi == .ED {
            switch numbers[0] {
            case 0:
                print("0J")
                for i in t.cursor.x ..< t.WIDTH {
                    clearCell(cell: &t.cells[i])
                }
            case 1:
                print("1J")
                for i in 0 ... t.cursor.x {
                    clearCell(cell: &t.cells[i])
                }
            case 2:
                print("2J")
                for i in 0 ..< t.HEIGHT {
                    clearRow(y: i)
                }
            default:
                print("Unknown number for J: \(numbers[0])")
            }
        } else if csi == .EL {
            let n = numbers[0]
            let yOffset = t.cursor.y * t.WIDTH
            
            if n == 0 {
                print("[\(n)K -- y: \(t.cursor.y) | x: \(t.cursor.x) to WIDTH")
                // If n is 0 (or missing), clear from cursor to the end of the line.
                // for c in x..<WIDTH { self.cells[c + (ay * WIDTH)].char = nil }
                for c in t.cursor.x ..< t.WIDTH {
                    clearCell(cell: &t.cells[c + yOffset])
                }
            } else if n == 1 {
                print("[\(n)K -- 0 to \(t.cursor.x)")
                // If n is 1, clear from cursor to beginning of the line.
                for c in 0 ..< t.cursor.x {
                    clearCell(cell: &t.cells[c + yOffset])
                }
            } else {
                print("[\(n)K -- CLEAR")
                // If n is 2, clear entire line. Cursor position does not change.
                for c in 0 ..< t.WIDTH {
                    clearCell(cell: &t.cells[c + yOffset])
                }
            }
        } else if csi == .IL {
            let n = numbers[0] == 0 ? 1 : numbers[0]

            for _ in 0 ..< n {
                insertLine()
            }
        } else if csi == .DL {
            let n = numbers[0] == 0 ? 1 : numbers[0]

            for _ in 0 ..< n {
                deleteLine()
            }
        } else if csi == .DCH {
            // delete chars
            print("Deleting \(numbers[0]) chars")
            let yOffset = t.cursor.y * t.WIDTH
            for i in t.cursor.x ..< t.WIDTH {
                t.cells[yOffset + i] = t.cells[yOffset + i + numbers[0]]
            }
        } else if csi == .PRIMARY_DA {
            print("TODO: Primary DA")
        } else if csi == .DSR {
            print("TODO: Device Status Report: \(numbers[0])")
            if numbers[0] == 6 {
                t.replyToShell("\u{1b}[\(t.cursor.y + 1);\(t.cursor.x + 1)R")
            }
        } else if csi == .WINDOW_MANIPULATION {
            print("TODO: Window Manipulation: \(numbers)")
        } else {
            print("UNKNOWN CSI")
        }
    }

    func parseOperatingSystemControl() {
        debugPrint(controlParser.c1!)
        if controlParser.numbers[0] == 10 {
            t.replyToShell("\u{1b}]10;rgb:f/ff/fff\u{1b}\\");
        } else if controlParser.numbers[0] == 11 {
            t.replyToShell("\u{1b}]11;rgb:f/ff/fff\u{1b}\\");
        }
    }

    func readNumber(_ input: Data, idx: inout Int) -> Int {
        var numbers = [Int](repeating: 0, count: 10)
        var count = 0

        let zero = 48
        let nine = 57
        while idx < input.count, input[idx] >= zero, input[idx] <= nine {
            numbers[count] = Int(input[idx]) - zero
            count += 1
            idx += 1
        }

        if count == 0 {
            return 0
        }

        var curr = 0
        var iter = count - 1
        for i in 0 ..< count {
            curr += numbers[i] * Int(pow(10.0, Double(iter)))
            iter -= 1
        }

        return curr
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
            : t.cells[((t.scrollBottom + 1) * t.WIDTH) ..< t.HEIGHT * t.WIDTH] // the rest

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
            : t.cells[((t.scrollBottom + 1) * t.WIDTH) ..< t.HEIGHT * t.WIDTH] // the rest

        t.cells = Array(a + b + c + d)
        clearRow(y: t.cursor.y)
    }
}
