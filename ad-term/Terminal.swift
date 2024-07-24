//
//  Terminal.swift
//  ad-term-cli
//
//  Created by Adam Dilger on 24/7/2024.
//

import Foundation

let WIDTH = 100;
let HEIGHT = 40;

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

class Terminal {
    var tty: TTY?;
    var cells = Array<Cell>();
    var currentLineIndex = 0;
    
    var fgColor: UInt16 = 0;
    var bgColor: UInt16 = 0;
    var inverted = false;
    
    var alternateCells = Array<Cell>();
    var alternateCurrentLineIndex = 0;
    var alternateX = 0;
    var alternateY = 0;

    var buffer: Data
    var lines: Array<line>;
    
    init() {
        self.buffer = Data()
        self.lines = [line(start: 0, end: 0)]
        for _ in 0..<WIDTH*HEIGHT { self.cells.append(Cell()); }
        
        self.tty = TTY(self);
    }
    
    func clearRow(y: Int) {
        let adjustedY = getAdjustedY(y: y);
        // //print("Clearing Row: cu: [\(self.currentLineIndex)] | \(y) : \(adjustedY)")
        
        for i in (WIDTH*adjustedY)..<(WIDTH*(adjustedY+1)) {
            self.cells[i].char = nil;
            self.cells[i].bgColor = 40
            self.cells[i].fgColor = 37
            self.cells[i].inverted = false
        }
    }

    func getAdjustedY(y: Int) -> Int {
        let ay = (self.currentLineIndex + y) % HEIGHT;
        return ay;
    }
    
    func draw() {
        var x = 0;
        var y = 0;
        self.fgColor = 37
        self.bgColor = 30
        self.currentLineIndex = 0;
        
        for i in 0..<HEIGHT {
            self.clearRow(y: i) // needed?
        }
        
        for line in self.lines {
            let s = line.start;
            let e = line.end;
            
            // //print(String(decoding: data[s..<e], as: UTF8.self))
            
            var idx = s;
            while idx < e {
                let b = self.buffer[idx];
                let bc = Character(UnicodeScalar(b))
                
                if b == ASC_ESC {
                    let peek = self.buffer[idx + 1];
                    if peek == ASC_L_SQUARE {
                        idx += 1;
                        self.readControlCode(idx: &idx, x: &x, y: &y);
                    } else if peek == ASC_P {
                        // xterm doesn't do anything with these... so ignore?
                        idx += 1
                        var p1 = idx + 1 < self.buffer.count ? self.buffer[idx + 1] : nil;
                        var p2 = idx + 2 < self.buffer.count ? self.buffer[idx + 2] : nil;
                        
                        while !(p1 == ASC_ESC && p2 == ASC_BACKSLASH) {
                            idx += 1
                            p1 = idx + 1 < self.buffer.count ? self.buffer[idx + 1] : nil;
                            p2 = idx + 2 < self.buffer.count ? self.buffer[idx + 2] : nil;
                        }
                        
                        idx += 2 // skip over peeks
                    } else if peek == ASC_R_SQUARE {
                        idx += 1
                        var p1 = idx + 1 < self.buffer.count ? self.buffer[idx + 1] : nil;
                        
                        while p1 != ASC_BELL {
                            idx += 1
                            p1 = idx + 1 < self.buffer.count ? self.buffer[idx + 1] : nil;
                        }
                        
                        idx += 1 // skip over peeks
                        // //print("TODO: [");
                    } else {
                        idx += 1;
                        //print("UNKNOWN ESCAPE CHAR: \(Character(UnicodeScalar(self.buffer[idx])))")
                    }
                } else if b == newline {
                    x = 0; // TODO: needed?
                    self.newLine(y: &y);
                } else if b == carriagereturn {
                    x = 0;
                } else if b == backspace {
                    x -= 1;
                } else {
                    let ay = self.getAdjustedY(y: y);
                    
                    var cellIndex = x + (ay * WIDTH)
                    
                    if bc == "\t" {
                        // insert tab chars to next multiple of 8
                        repeat {
                            self.cells[cellIndex].char = " "
                            self.cells[cellIndex].bgColor = bgColor
                            self.cells[cellIndex].fgColor = fgColor
                            self.cells[cellIndex].inverted = inverted
                            if x + 1 == WIDTH {
                                break;
                            }
                            x += 1;
                            cellIndex += 1;
                        } while (x % 8 != 0)
                    } else {
                        self.cells[cellIndex].bgColor = bgColor
                        self.cells[cellIndex].fgColor = fgColor
                        self.cells[cellIndex].inverted = inverted
                        self.cells[cellIndex].char = bc
                        
                        if x + 1 == WIDTH {
                            x = 0;
                            
                            self.newLine(y: &y);
                        } else {
                            x += 1;
                        }
                    }
                }
                
                idx += 1;
            }
        }
        
        let ay = self.getAdjustedY(y: y);
        self.cells[x + (ay * WIDTH)].inverted = true
        
        let nc = NotificationCenter.default
        nc.post(name: Notification.Name("TerminalDataUpdate"), object: nil)
    }
    
    func newLine(y: inout Int) {
        if y + 1 < HEIGHT {
            // we're at the bottom of the grid, so don't "move down"
            // everything will shift up instead
            y += 1;
        } else {
            // y has stayed the same, but we need to shift all values up one
            self.currentLineIndex += 1;
        }
        
        self.clearRow(y: y);
    }
    
    func readControlCode(idx: inout Int, x: inout Int, y: inout Int) {
        var peek: UInt8? = self.buffer[idx + 1];
        
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
            peek = idx + 1 < self.buffer.count ? self.buffer[idx + 1] : nil;
        }
        
        // we've parsed some rando characters, now parse out the number array
        var numbers = Array<UInt16>();
        
        while peek == ASC_SEMI_COLON || (ASC_0 <= peek! && peek! <= ASC_9) {
            while ASC_0 <= peek! && peek! <= ASC_9 {
                if numbers.isEmpty { numbers.append(0); }
                
                numbers[numbers.count - 1] *= 10
                numbers[numbers.count - 1] += UInt16(peek! - ASC_0)
                
                idx += 1;
                peek = idx + 1 < self.buffer.count ? self.buffer[idx + 1] : nil;
            }
            
            if peek == ASC_SEMI_COLON {
                numbers.append(0);
                idx += 1;
                peek = idx + 1 < self.buffer.count ? self.buffer[idx + 1] : nil;
            }
        }
        
        if peek == ASC_h {
            idx += 1;
            
            var n: UInt16 = 1;
            if numbers.count > 0 && numbers[0] != 0 { n = numbers[0] }
            
            if n == 1049 {
                self.alternateCells = self.cells;
                self.alternateX = x;
                self.alternateY = y;
                self.alternateCurrentLineIndex = self.currentLineIndex;
                
                self.cells = Array();
                for _ in 0..<WIDTH*HEIGHT { self.cells.append(Cell()); }
                x = 0;
                y = 0;
                self.currentLineIndex = 0;
                
                //print("Alternate Buffer: ON")
            } else {
                //print("\(questionMark ? "?" : "")\(n)h")
            }
        } else if peek == ASC_l {
            idx += 1;
            
            var n: UInt16 = 1;
            if numbers.count > 0 && numbers[0] != 0 { n = numbers[0] }
            
            if n == 1049 {
                self.cells = self.alternateCells;
                self.alternateCells = Array();
                x = self.alternateX;
                y = self.alternateY;
                
                self.currentLineIndex = self.alternateCurrentLineIndex;
                self.alternateCurrentLineIndex = 0;
                //print("Alternate Buffer: OFF")
            }
        } else if peek == ASC_K {
            idx += 1
            
            var n: UInt16 = 0;
            if numbers.count > 0 && numbers[0] != 0 { n = numbers[0] }
            
            let ay = getAdjustedY(y: y)
            
            if n == 0 {
                //print("[\(n)K -- \(x) to WIDTH")
                // If n is 0 (or missing), clear from cursor to the end of the line.
                for c in x..<WIDTH { self.cells[c + (ay * WIDTH)].char = nil }
            } else if n == 1 {
                //print("[\(n)K -- 0 to \(x)")
                // If n is 1, clear from cursor to beginning of the line.
                for c in 0..<idx { self.cells[c + (ay * WIDTH)].char = nil }
            } else {
                //print("[\(n)K -- CLEAR")
                // If n is 2, clear entire line. Cursor position does not change.
                for c in 0..<WIDTH { self.cells[c + (ay * WIDTH)].char = nil }
            }
        } else if peek == ASC_H {
            idx += 1;
            
            var n: UInt16 = 1;
            if numbers.count > 0 && numbers[0] != 0 { n = numbers[0] }
            
            var m: UInt16 = 1;
            if numbers.count > 1 && numbers[1] != 0 { m = numbers[1] }
            
            //print("\(n);\(m)H")
            
            x = Int(m) - 1;
            y = Int(n) - 1;
            
            // self.currentLineIndex = y;
        } else if peek == ASC_J {
            idx += 1;
            
            var n: UInt16 = 0;
            if numbers.count > 0 { n = numbers[0] }
            
            // //print("\(n)J")
            if n == 0 {
                // If n is 0 (or missing), clear from cursor to end of screen.
                //print("TODO: // [0J")
            } else if n == 1 {
                // If n is 1, clear from cursor to beginning of the screen.
                //print("TODO: // [1J")
            } else  {
                // If n is 2, clear entire screen
                // If n is 3, clear entire screen and delete all lines saved in the scrollback buffer
                //print("TODO: // [\(n)J")
                
                for i in 0..<WIDTH*HEIGHT {
                    self.cells[i].char = nil;
                }
            }
        } else if peek == ASC_m && numbers.count > 1 {
            idx += 1;
            
            let n = numbers[0]
            let m = numbers[1]
            
            //print("TODO: [\(n);\(m)m")
        } else if peek == ASC_m {
            idx += 1;
            
            var n: UInt16 = 0;
            if numbers.count > 0 { n = numbers[0] }
            
            switch (n) {
            case 0:  
                fgColor = 37
                bgColor = 40
                inverted = false;
                print("[\(n)m setting Normal (default)");
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
            
            var n: UInt16 = 0;
            if numbers.count > 0 { n = numbers[0] }
            
            var m: UInt16 = 0;
            if numbers.count > 1 { m = numbers[1] }
            
            //print("TODO: [\(n);\(m)r")
        } else if peek == ASC_t {
            idx += 1;
            
            var n: UInt16 = 0;
            if numbers.count > 0 { n = numbers[0] }
            
            var m: UInt16 = 0;
            if numbers.count > 1 { m = numbers[1] }
            
            //print("TODO: [\(n);\(m)t")
        } else if peek == ASC_L {
            idx += 1;
            var n: UInt16 = 1;
            if numbers.count > 0 { n = numbers[0] }
            
            for _ in 0..<n {
                self.newLine(y: &y)
            }
        } else {
            idx += 1;
            //print("----- UNKNOWN CSI: [\(Character(UnicodeScalar(self.buffer[idx])))")
        }
    }
}
