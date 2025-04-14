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

    var numCount = 0
    var digitCount = 0
    var numbers = [0, 0, 0, 0]

    enum WhereAmIParsing {
        case New
        case FE

        case CSI
        case SGR

        case OSC
    }

    func parse(_ input: Data, index: Int) {
        var idx = index

        if idx == input.count {
            print("ControlSequenceParser idx overflow")
            return
        }

        while idx < input.count {
            var c = input[idx]

            if type == .New {
                if c == chars.ESCAPE {
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
                var questionMark = false
                var greaterThan = false

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
                    digitCount = 0
                    continue
                } else if c >= 48, c <= 57 {}

                numbers[0] = readNumber(input, idx: &idx)
                numCount = 1

                if c == chars.SQUARE_BRACKET_L {
                    c += 1
                    c1 = .CSI
                    type = .CSI
                    continue
                } else if c == chars.SQUARE_BRACKET_R {
                    c += 1
                    c1 = .OSC
                    type = .OSC
                    continue
                } else { print(".FE ERROR") }
            }
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

    enum C1 {
        case CSI // Control Sequence Introducer
        case ST // String Terminator
        case OSC // Operating System Command
    }

    enum CSI {
        case CUU // Cursor Up
        case CUD // Cursor Down
        case CUF // Cursor Forward
        case CUB // Cursor Back
        case CUP // Cursor Position
        case SU // Scroll Up
        case SD // Scroll Down
        case SGR // Select Graphics Rendition
        case DECTCEM_ON // Shows the cursor
        case DECTCEM_OFF // Hides the cursor
    }
}
