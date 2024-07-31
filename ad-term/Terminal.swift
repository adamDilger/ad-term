//
//  Terminal.swift
//  ad-term-cli
//
//  Created by Adam Dilger on 24/7/2024.
//

import Foundation

// var WIDTH = 80;
// var HEIGHT = 24;

struct Cell {
    var char: Character?;
    var fgColor: UInt16?;
    var bgColor: UInt16?;
    var inverted = false
}

struct line {
    var start: Int;
    var end: Int;
}

struct point {
    var x: Int
    var y: Int
}

class Terminal {
    var tty: TTY?;
    var cells = Array<Cell>();
    
    var fgColor: UInt16 = 0;
    var bgColor: UInt16 = 0;
    var inverted = false;
    
    var alternateCells = Array<Cell>();
    var alternateX = 0;
    var alternateY = 0;

    var cursor = point(x: 0, y: 0)
    var currentLineBufferIndex = 0;
    
    var buffer: Data
    
    var scrollTop: Int;
    var scrollBottom: Int;
    
    var WIDTH: Int;
    var HEIGHT: Int;

    init(width: Int, height: Int) {
        self.WIDTH = width;
        self.HEIGHT = height;
        self.buffer = Data()
        for _ in 0..<WIDTH*HEIGHT { self.cells.append(Cell()); }
        
        self.scrollTop = 0;
        self.scrollBottom = HEIGHT - 1;
        
        self.WIDTH = width;
        self.HEIGHT = height;

        self.tty = TTY(self);
    }
    
    func resize(_ width: Int, _ height: Int) {
        if self.scrollBottom == HEIGHT - 1 {
            self.scrollBottom = height - 1;
        }

        self.WIDTH = width;
        self.HEIGHT = height;

        self.cells = [];
        for _ in 0..<WIDTH*HEIGHT { self.cells.append(Cell()); }
        
        self.currentLineBufferIndex = 0;
        self.cursor = point(x: 0, y: 0)
        
    }
    
    func clearCell(cell: inout Cell) {
        cell.char = nil;
        cell.bgColor = 40
        cell.fgColor = 37
        cell.inverted = false
    }
    
    func clearRow(y: Int) {
        for i in (WIDTH*y)..<(WIDTH*(y+1)) {
            self.clearCell(cell: &self.cells[i])
        }
    }
    
    func peek(_ idx: Int, by: Int = 1) -> UInt8? {
        return idx + by < self.buffer.count ? self.buffer[idx + by] : nil;
    }

    func draw() {
        var idx = currentLineBufferIndex;
        while idx < self.buffer.count {
            // print(String(decoding: data[s..<e], as: UTF8.self))
            let b = self.buffer[idx];
            
            if b == ASC_ESC {
                let peek = self.peek(idx)
                
                if peek == ASC_L_SQUARE {
                    idx += 1;
                    self.readControlCode(idx: &idx);
                } else if peek == ASC_P {
                    // xterm doesn't do anything with these... so ignore?
                    idx += 1
                    var p1 = self.peek(idx, by: 1)
                    var p2 = self.peek(idx, by: 2)

                    while !(p1 == ASC_ESC && p2 == ASC_BACKSLASH) {
                        idx += 1
                        p1 = self.peek(idx, by: 1)
                        p2 = self.peek(idx, by: 2)
                    }
                    
                    idx += 2 // skip over peeks
                    print("TODO: esc P")
                } else if peek == ASC_R_SQUARE {
                    idx += 1
                    var p1 = self.peek(idx)
                    
                    while p1 != ASC_BELL {
                        idx += 1
                        p1 = self.peek(idx)
                    }
                    
                    idx += 1 // skip over peeks
                    print("TODO: esc ]");
                } else {
                    print("UNKNOWN ESCAPE CHAR: \(Character(UnicodeScalar(peek ?? 0)))")
                }
            } else if b == ASC_BELL {
                print("BELL");
            } else if b == newline {
                cursor.x = 0; // TODO: needed?
                self.newLine();
            } else if b == carriagereturn {
                cursor.x = 0;
            } else if b == backspace {
                cursor.x -= 1;
            } else {
                var cellIndex = cursor.x + (cursor.y * WIDTH)
                
                if b == tab {
                    // insert tab chars to next multiple of 8
                    repeat {
                        self.cells[cellIndex].char = " "
                        self.cells[cellIndex].bgColor = bgColor
                        self.cells[cellIndex].fgColor = fgColor
                        self.cells[cellIndex].inverted = inverted
                        if cursor.x + 1 == WIDTH {
                            break;
                        }
                        cursor.x += 1;
                        cellIndex += 1;
                    } while (cursor.x % 8 != 0)
                } else {
                    self.cells[cellIndex].bgColor = bgColor
                    self.cells[cellIndex].fgColor = fgColor
                    self.cells[cellIndex].inverted = inverted
                    self.cells[cellIndex].char = Character(UnicodeScalar(b));
                    
                    if cursor.x + 1 == WIDTH {
                        cursor.x = 0;
                        
                        self.newLine();
                    } else {
                        cursor.x += 1;
                    }
                }
            }
            
            idx += 1;
        }
        
        currentLineBufferIndex = self.buffer.count;

        let nc = NotificationCenter.default
        nc.post(name: Notification.Name("TerminalDataUpdate"), object: nil)
    }
    
    func describe() {
        var out: [Character] = []
        
        out += "------------------------------------";
        
        for i in 0..<HEIGHT {
            out += "\(i)  |";
            
            for j in 0..<WIDTH {
                out.append(self.cells[j + (i*WIDTH)].char ?? Character(" "));
            }
            out += "\n";
        }
        
        print(String(out) + "------------------------------------");
    }
    
    func deleteLine() {
        // get 0 to < y
        let a = self.cells[0 ..< (self.cursor.y * WIDTH)]
        
        // get the rest of the scroll region (-1)
        let b = self.cells[((self.cursor.y + 1) * WIDTH) ..< ((self.scrollBottom + 1) * WIDTH)]
        
        // get the current y line (this will be cleared)
        let c = self.cells[(self.cursor.y * WIDTH) ..< ((self.cursor.y + 1) * WIDTH)]
        
        let d = self.scrollBottom == HEIGHT - 1
            ? []
            : self.cells[((self.scrollBottom + 1) * WIDTH)..<HEIGHT*WIDTH] // the rest

        self.cells = Array(a + b + c + d)
        self.clearRow(y: self.scrollBottom)
    }
    
    func insertLine() {
        // get 0 to < y
        let a = self.cells[0 ..< (self.cursor.y * WIDTH)]
        
        // get last line of scroll region, this is the "new" line
        let b = self.cells[(self.scrollBottom * WIDTH) ..< ((self.scrollBottom + 1) * WIDTH)]
        
        // get the rest of the scroll region (-1)
        let c = self.cells[((self.cursor.y) * WIDTH) ..< ((self.scrollBottom) * WIDTH)]
        
        let d = self.scrollBottom == HEIGHT - 1
            ? []
            : self.cells[((self.scrollBottom + 1) * WIDTH)..<HEIGHT*WIDTH] // the rest

        
        self.cells = Array(a + b + c + d)
        self.clearRow(y: self.cursor.y)
    }

    func newLine() {
        let shouldScroll = self.cursor.y == self.scrollBottom

        if shouldScroll == false && self.cursor.y + 1 < HEIGHT {
            self.cursor.y += 1;
        }
        
        if shouldScroll {
            // we're at the bottom of the grid, so don't "move down"
            // everything will shift up instead
            let a = self.cells[0 ..< (self.scrollTop * WIDTH)] // everything up until the scroll region, should be 0 for normal operation
            let b = self.cells[((self.scrollTop + 1) * WIDTH) ..< ((self.scrollBottom + 1) * WIDTH)] // scroll region start + 1 (as we're 'scrolling', so skip first line)
            let c = self.cells[((self.scrollTop) * WIDTH) ..< ((self.scrollTop + 1) * WIDTH)] // first line of scroll region
            let d = self.scrollBottom == HEIGHT - 1
                ? []
                : self.cells[((self.scrollBottom + 1) * WIDTH)..<HEIGHT*WIDTH] // the rest

            self.cells = Array(a + b + c + d)
            self.clearRow(y: self.cursor.y)
        }
    }
    
    func readControlCode(idx: inout Int) {
        var peek = self.peek(idx)
        
        if peek == nil { return; }

        var questionMark = false;
//        var greaterThan = false;
//        var lessThan = false;
//        var equals = false;
        
        while peek! >= ASC_LESS_THAN && peek! <= ASC_QUESTION_MARK {
            switch peek {
            case ASC_QUESTION_MARK: questionMark = true;
//            case ASC_GREATER_THAN: greaterThan = true;
//            case ASC_LESS_THAN: lessThan = true;
//            case ASC_EQUALS: equals = true;
            default: print("UNKNOWN: \(peek!)");
            }
            
            idx += 1;
            peek = self.peek(idx)
        }
        
        if peek == nil { return; }

        // we've parsed some rando characters, now parse out the number array
        var numbers: [UInt16] = [0, 0, 0, 0]
        
        var ni = 0;
        while peek == ASC_SEMI_COLON || (ASC_0 <= peek! && peek! <= ASC_9) {
            while peek != nil && ASC_0 <= peek! && peek! <= ASC_9 {
                numbers[ni] *= 10
                numbers[ni] += UInt16(peek! - ASC_0)
                
                idx += 1;
                peek = self.peek(idx);
            }
            
            if peek == ASC_SEMI_COLON {
                ni += 1
                idx += 1;
                peek = self.peek(idx);
            }
            
            if peek == nil { return; }
        }
        
        if peek == nil { return; }
        
        if peek == ASC_C {
            // move cursor right
            idx += 1;
            let n = numbers[0] == 0 ? 1 : numbers[0]
            cursor.x += Int(n)
        } else if peek == ASC_h {
            idx += 1;
            
            let n = numbers[0] == 0 ? 1 : numbers[0]

            if n == 1049 {
                self.alternateCells = self.cells;
                self.alternateX = cursor.x;
                self.alternateY = cursor.y;
                
                self.cells = Array();
                for _ in 0..<WIDTH*HEIGHT { self.cells.append(Cell()); }
                cursor.x = 0;
                cursor.y = 0;
                
                print("Alternate Buffer: ON")
            } else {
                print("\(questionMark ? "?" : "")\(n)h")
            }
        } else if peek == ASC_l {
            idx += 1;
            
            let n = numbers[0] == 0 ? 1 : numbers[0]

            if n == 1049 {
                self.cells = self.alternateCells;
                self.alternateCells = Array();
                cursor.x = self.alternateX;
                cursor.y = self.alternateY;
                
                print("Alternate Buffer: OFF")
            } else {
                print("UNKWOWN \(n)l")
            }
        } else if peek == ASC_K {
            idx += 1
            
            let n = numbers[0]
            if n == 0 {
                print("[\(n)K -- y: \(cursor.y) | x: \(cursor.x) to WIDTH")
                // If n is 0 (or missing), clear from cursor to the end of the line.
                // for c in x..<WIDTH { self.cells[c + (ay * WIDTH)].char = nil }
                for c in cursor.x..<WIDTH { clearCell(cell: &self.cells[c + (cursor.y * WIDTH)]) }
            } else if n == 1 {
                print("[\(n)K -- 0 to \(cursor.x)")
                // If n is 1, clear from cursor to beginning of the line.
                for c in 0..<idx { clearCell(cell: &self.cells[c + (cursor.y * WIDTH)]) }
            } else {
                print("[\(n)K -- CLEAR")
                // If n is 2, clear entire line. Cursor position does not change.
                for c in 0..<WIDTH { clearCell(cell: &self.cells[c + (cursor.y * WIDTH)]) }
            }
        } else if peek == ASC_H {
            idx += 1;
            
            let n = numbers[0] == 0 ? 1 : numbers[0]
            let m = numbers[1] == 0 ? 1 : numbers[1]
            
            print("\(n);\(m)H")
            
            cursor.x = Int(m) - 1;
            cursor.y = Int(n) - 1;
        } else if peek == ASC_J {
            idx += 1;
            
            let n = numbers[0]

            if n == 0 {
                // If n is 0 (or missing), clear from cursor to end of screen.
                print("TODO: // [0J")
            } else if n == 1 {
                // If n is 1, clear from cursor to beginning of the screen.
                print("TODO: // [1J")
            } else  {
                // If n is 2, clear entire screen
                // If n is 3, clear entire screen and delete all lines saved in the scrollback buffer
                print("TODO: // [\(n)J")
                
                for i in 0..<WIDTH*HEIGHT {
                    clearCell(cell: &self.cells[i]);
                }
            }
        } else if peek == ASC_m && numbers[1] > 0 {
            idx += 1;
            
            let n = numbers[0]
            let m = numbers[1]
            
            print("TODO: [\(n);\(m)m")
        } else if peek == ASC_m {
            idx += 1;
            
            let n = numbers[0]

            switch (n) {
            case 0:  
                fgColor = 37
                bgColor = 40
                inverted = false;
            case 1:  print("[\(n)m setting Bold");
            case 7:  inverted = true;
            case 4:  print("[\(n)m setting Underlined");
            case 30: fgColor = n; // Black
            case 31: fgColor = n; // Red
            case 32: fgColor = n; // Green
            case 33: fgColor = n; // Yellow
            case 34: fgColor = n; // Blue
            case 35: fgColor = n; // Magenta
            case 36: fgColor = n; // Cyan
            case 37: fgColor = n; // White
            case 39: fgColor = 37; //default (original)
            case 40: bgColor = n // Black
            case 41: bgColor = n // Red
            case 42: bgColor = n // Green
            case 43: bgColor = n // Yellow
            case 44: bgColor = n // Blue
            case 45: bgColor = n // Magenta
            case 46: bgColor = n // Cyan
            case 47: bgColor = n // White
            case 49: bgColor = 40; //default (original)
            default: print("TODO: color [\(n)m")
            }

        } else if peek == ASC_r {
            idx += 1;
            
            let n = numbers[0] == 0 ? 1 : numbers[0]
            let m = numbers[1] == 0 ? UInt16(HEIGHT) : numbers[1]
            
            self.scrollTop = Int(n - 1);
            self.scrollBottom = Int(m - 1);
            print("Setting scroll bounds: [\(n);\(m)r")
        } else if peek == ASC_t {
            idx += 1;
            
            let n = numbers[0]
            let m = numbers[1]
            let o = numbers[2]
            
            print("TODO: [\(n);\(m);\(o)t")
        } else if peek == ASC_L {
            idx += 1;
            let n = numbers[0] == 0 ? 1 : numbers[0]

            for _ in 0..<n {
                self.insertLine()
            }
        } else if peek == ASC_M {
            idx += 1;
            let n = numbers[0] == 0 ? 1 : numbers[0]

            for _ in 0..<n {
                self.deleteLine()
            }
        } else {
            idx += 1;
            print("----- UNKNOWN CSI: [\(Character(UnicodeScalar(self.buffer[idx])))")
        }
    }
}
