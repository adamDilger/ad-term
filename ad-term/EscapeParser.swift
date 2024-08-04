//
//  EscapeParser.swift
//  ad-term
//
//  Created by Adam Dilger on 4/8/2024.
//

import Foundation

class EscapeParser {
    var isParsing = false;
    var C1: UInt8?
    var CSI: UInt8?

    var numbers: [Int] = [0, 0, 0, 0]
    var numberIndex = 0
    
    func reset() {
        numbers = [0, 0, 0, 0]
        numberIndex = 0;
        isParsing = false;
    }
    
    func parse(_ buffer: Data, idx: inout Int) {
        isParsing = true;
        
        var peek = self.peek(buffer, idx)
        if peek == nil {
            // still parsing?
            return;
        }
        
        // assume we're starting from blank
        
        while peek != nil && peek! >= 0x30 && peek! <= 0x3F {
            if peek == ASC_SEMI_COLON {
                // new number
                numberIndex += 1
                idx += 1;
                peek = self.peek(buffer, idx);
            } else /* TODO: assume number for now */ {
                numbers[numberIndex] *= 10
                numbers[numberIndex] += Int(peek! - ASC_0)
                
                idx += 1;
                peek = self.peek(buffer, idx);
            }
        }
        
        if peek == nil {
            // still parsing?
            return;
        }

        switch (peek) {
        case CSI_CUU,
        CSI_CUD,
        CSI_CUF,
        CSI_CUB,
        CSI_CNL,
        CSI_CPL,
        CSI_CHA,
        CSI_CUP,
        CSI_ED,
        CSI_EL,
        CSI_SU,
        CSI_SD,
        CSI_HVP,
        CSI_SGR:
            CSI = peek;
        default:
            print("UNKNOWN CSI: \(peek!)")
        }

        isParsing = false;
    }
    
    func peek(_ buffer: Data, _ idx: Int, by: Int = 1) -> UInt8? {
        return idx + by < buffer.count ? buffer[idx + by] : nil;
    }
    
}

var C0_BEL: UInt8 = 0x07    // ^G    Bell    Makes an audible noise.
var C0_BS:  UInt8 = 0x08    // ^H    Backspace    Moves the cursor left (but may "backwards wrap" if cursor is at start of line).
var C0_HT:  UInt8 = 0x09    // ^I    Tab    Moves the cursor right to next multiple of 8.
var C0_LF:  UInt8 = 0x0A    // ^J    Line Feed    Moves to next line, scrolls the display up if at bottom of the screen.
var C0_FF:  UInt8 = 0x0C    // ^L    Form Feed    Move a printer to top of next page.
var C0_CR:  UInt8 = 0x0D    // ^M    Carriage Return    Moves the cursor to column zero.
var C0_ESC: UInt8 = 0x1B    // ^[    Escape    Starts all the escape sequences

var CSI_CUU	= Character("A").asciiValue!	// Cursor Up	Moves the cursor n (default 1) cells in the given direction.
var CSI_CUD	= Character("B").asciiValue!	// Cursor Down
var CSI_CUF	= Character("C").asciiValue!	// Cursor Forward
var CSI_CUB	= Character("D").asciiValue!	// Cursor Back
var CSI_CNL	= Character("E").asciiValue!	// Cursor Next Line	Moves cursor to beginning of the line n (default 1) lines down. (not ANSI.SYS)
var CSI_CPL	= Character("F").asciiValue!	// Cursor Previous Line	Moves cursor to beginning of the line n (default 1) lines up. (not ANSI.SYS)
var CSI_CHA	= Character("G").asciiValue!	// Cursor Horizontal Absolute	Moves the cursor to column n (default 1). (not ANSI.SYS)
var CSI_CUP	= Character("H").asciiValue!	// Cursor Position	Moves the cursor to row n, column m.
var CSI_ED	= Character("J").asciiValue!	// Erase in Display
var CSI_EL	= Character("K").asciiValue!	// Erase in Line	Erases part of the line. 
var CSI_SU	= Character("S").asciiValue!	// Scroll Up	Scroll whole page up by n (default 1) lines.
var CSI_SD	= Character("T").asciiValue!	// Scroll Down	Scroll whole page down by n (default 1) lines.
var CSI_HVP	= Character("f").asciiValue!	// Horizontal Vertical Position
var CSI_SGR	= Character("m").asciiValue!	// Select Graphic Rendition



// CSI 5i		AUX Port On	Enable aux serial port usually for local serial printer
// CSI 4i		AUX Port Off	Disable aux serial port usually for local serial printer
// CSI 6n	DSR	Device Status Report	Reports the cursor position (CPR) by transmitting ESC[n;mR, where n is the row and m is the column.


// xterm specifics
var CSI_SM = Character("h").asciiValue!
var CSI_DECSTBM = Character("r").asciiValue!
var CSI_DECSLPP = Character("t").asciiValue!

var CSI_DL = Character("M").asciiValue!
var CSI_IL = Character("L").asciiValue!

/* TODO: this actually starts with a ? */
var CSI_DECRST = Character("l").asciiValue!

