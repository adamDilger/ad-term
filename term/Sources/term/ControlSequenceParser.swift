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
    
    var numCount = 0
    var numbers = [0, 0, 0, 0]

    enum WhereAmIParsing {
        case New
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
            let c = input[idx]

            if type == .New {
                if c == chars.ESCAPE {
                    reset()
                    
                    idx += 1
                    isParsing = true
                    continue
                } else if c >= 64 || c <= 95 {
                    type = .FE
                    continue
                } else { print(".New ERROR") }
            } else if type == .FE {
                if c == chars.SQUARE_BRACKET_L {
                    idx += 1
                    c1 = .CSI
                    type = .CSI
                    continue
                } else if c == chars.SQUARE_BRACKET_R {
                    idx += 1
                    c1 = .OSC
                    type = .OSC
                    continue
                } else { print(".FE ERROR") }
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
                        numbers[numCount] = (numbers[numCount] * 10) + v
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
                        case chars.J: .ED
                        case chars.m: .SGR
                        default: nil
                        }
                    }
                    
                    idx += 1
                    type = .New
                    
                    break;
                }
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
        numCount = 0
    }

    enum C1 {
        case CSI // Control Sequence Introducer
        case ST // String Terminator
        case OSC // Operating System Command
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
        /// Select Graphics Rendition
        case SGR
        /// DEC Private Mode Set
        case DECSET
        /// DEC Private Mode Reset
        case DECRST
    }
}
