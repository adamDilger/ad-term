// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation

public func OHMY() -> String {
    return "FUK";
}

let ESCAPE = 27;

struct BufLine {
    var s: Int;
    var e: Int;
}

struct Cell {
    var char: UInt8?;
    var fgColor: UInt16?;
    var bgColor: UInt16?;
    var inverted = false
}

class Parser {
    var bgColor: Int = 0;
    var fgColor: Int = 0;
    
    var width = 0;
    var height = 0;
    var x = 0;
    var y = 0;
    
    var cells: Array<Cell> = []

    let buf: Data;
    
    init(buffer: Data) {
        self.buf = buffer;
    }
    
    func resize(width: Int, height: Int) {
        self.width = width
        self.height = height
        cells = Array<Cell>(repeating: Cell(), count: width * height);
        // TODO: redraw
    }

    func parseLines(lines: Array<BufLine>) {
        for line in lines {
            var idx: Int = line.s;
            
            while idx <= line.e {
                // read until escape char
                while (idx <= line.e && buf[idx] != ESCAPE) {
                    print(Character(UnicodeScalar(buf[idx])))
                    cells[(y * width) + x].char = buf[idx]
                    incX()
                    idx += 1;
                }
                
                if idx >= line.e {
                    break;
                }

                if (buf[idx] == ESCAPE) {
                    idx += 1;
                    parseEscapeCode(line: line, idx: &idx);
                }
            }
            
            // TODO: maybe this needs to check if there's a new line?
            y += 1;
            x = 0;
        }
    }
    
    func incX() {
        x += 1;
        if x == width {
            x = 0;
            y += 1;
            if y == height { print("TODO: scroll") }
        }
    }

    func parseEscapeCode(line: BufLine, idx: inout Int) {
        if (buf[idx] == Character("[").asciiValue) {
            idx += 1;
            parseControlCode(line: line, idx: &idx);
        }
    }
    
    func parseControlCode(line: BufLine, idx: inout Int) {
        let number = readNumber(line: line, idx: &idx);
        if (buf[idx] == Character("m").asciiValue) {
            idx += 1;
            self.fgColor = number;
        }
    }
    
    func readNumber(line: BufLine, idx: inout Int) -> Int {
        var numbers = [Int](repeating: 0, count: 10)
        var count = 0;
        
        while (buf[idx] >= Character("0").asciiValue! && buf[idx] <= Character("9").asciiValue!) {
            numbers[count] = Int(buf[idx]) - 48;
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

