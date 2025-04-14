//
//  ControlSequenceParser.swift
//  term
//
//  Created by Adam Dilger on 13/4/2025.
//

import Foundation

class ControlSequenceParser {
    var isParsing = false
    var type: WhereAmIParsing = .New

    var c1: C1?
    var csi: CSI?

    var questionMark = false
    var greaterThan = false
    
    var numCount = 1
    var numbers = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    enum WhereAmIParsing {
        case New
        case Done
        case FE

        case CSI
        case SGR

        case OSC
    }

    func parse(_ input: Data, index: Int) -> Int {
        var idx = index

        if idx == input.count {
            print("ControlSequenceParser idx overflow")
            return index
        }

        while idx < input.count {
            if type == .Done {
                type = .New
                isParsing = false
                break;
            }
            
            let c = input[idx]

            if type == .New {
                if c == chars.ESCAPE {
                    reset()
                    idx += 1
                    isParsing = true
                } else if c >= 64 || c <= 95 {
                    type = .FE
                } else {
                    print(".New ERROR")
                }
            } else if type == .FE {
                idx += 1
                
                if c == chars.SQUARE_BRACKET_L {
                    c1 = .CSI
                    type = .CSI
                } else if c == chars.EQUALS {
                    c1 = .DECPAM
                    type = .New
                } else if c == chars.SQUARE_BRACKET_R {
                    c1 = .OSC
                    type = .OSC
                }
                else {
                    print(".FE ERROR: \(Character(UnicodeScalar(c)))")
                    type = .Done
                }
            } else if type == .CSI {
                if c == chars.QUESTION {
                    idx += 1
                    questionMark = true
                    continue
                } else if c == chars.GREATER_THAN {
                    // unsure
                    idx += 1
                    greaterThan = true
                    continue
                } else if c == chars.SEMI_COLON {
                    // end parsing a number
                    idx += 1
                    numCount += 1
                    continue
                } else if c >= 48, c <= 57 {
                    while idx < input.count && input[idx] >= 48 && input[idx] <= 57 {
                        let v = Int(input[idx]) - 48
                        numbers[numCount - 1] = (numbers[numCount - 1] * 10) + v
                        idx += 1
                    }
                } else if c >= 0x40 && c <= 0x7E {
                    // END OF CSI
                    if questionMark {
                        csi = switch Int(c) {
                        case chars.h: .DECSET
                        case chars.l: .DECRST
                        default: nil
                        }
                    } else {
                        csi = switch Int(c) {
                        case chars.A: .CUU
                        case chars.B: .CUD
                        case chars.C: .CUF
                        case chars.D: .CUB
                        case chars.H: .CUP
                        case chars.L: .IL
                        case chars.K: .EL
                        case chars.J: .ED
                        case chars.c: .PRIMARY_DA
                        case chars.m: .SGR
                        case chars.n: .DSR
                        case chars.r: .DECSTBM
                        case chars.t: .WINDOW_MANIPULATION
                        default: nil
                        }
                    }
                    
                    idx += 1
                    type = .Done
                    break;
                } else {
                    idx += 1
                    print("UNKNOWN CSI: \(Character(UnicodeScalar(c)))")
                }
            } else if type == .OSC {
                // idx += 1
                print("OSC CHAR: \((Character(UnicodeScalar(c))))")
                
                if c == chars.SEMI_COLON {
                    // end parsing a number
                    idx += 1
                    numCount += 1
                    continue
                } else if c >= 48, c <= 57 {
                    while idx < input.count && input[idx] >= 48 && input[idx] <= 57 {
                        let v = Int(input[idx]) - 48
                        numbers[numCount - 1] = (numbers[numCount - 1] * 10) + v
                        idx += 1
                    }
                } else if c == chars.BELL {
                    idx += 1
                    type = .Done
                } else {
                    idx += 1
                    print("Consuming OSC char: \(Character(UnicodeScalar(c)))")
                }
            } else {
                print("BREAKING UNKNOWN NEXT CHAR: \(Character(UnicodeScalar(c)))")
                
                idx += 1
                type = .Done
                break;
            }
        }
        
        return idx
    }
    
    func reset() {
        isParsing = false
        type = .New
        
        c1 = nil
        csi = nil
        
        questionMark = false
        greaterThan = false
        
        for i in 0..<numbers.count { numbers[i] = 0 }
        numCount = 1
    }

    enum C1 {
        /// Control Sequence Introducer
        case CSI
        /// String Terminator
        case ST
        /// Operating System Command
        case OSC
        /// Application Keypad
        case DECPAM
    }

    enum CSI {
        /// Cursor Up
        case CUU
        /// Cursor Down
        case CUD
        /// Cursor Forward
        case CUF
        /// Cursor Back
        case CUB
        /// Cursor Position
        case CUP
        /// Scroll Up
        case SU
        /// Scroll Down
        case SD
        /// Erase in Display
        case ED
        /// Erase in Line
        case EL
        /// Insert Line
        case IL
        /// Delete Line
        case DL
        /// Delete Character
        case DCH
        /// Device Status Report
        case DSR
        /// Select Graphics Rendition
        case SGR
        /// DEC Private Mode Set
        case DECSET
        /// DEC Private Mode Reset
        case DECRST
        /// Scrolling region
        case DECSTBM
        /// Window manipulation (t)
        case WINDOW_MANIPULATION
        /// primary DA
        case PRIMARY_DA
    }
}
