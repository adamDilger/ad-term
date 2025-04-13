//
//  ControlSequenceParser.swift
//  term
//
//  Created by Adam Dilger on 13/4/2025.
//

import Foundation

class ControlSequenceParser {
    var isParsing = false

    var c1: C1?
    var csi: CSI?

    var numCount = 0
    var numbers = [0, 0, 0, 0]

    enum WhereAmIParsing {
        case New
        case FE
        case CSI
        case SGR
    }

    func parse(_ input: Data, idx: Int) {
        if idx == input.count {
            print("ControlSequenceParser idx overflow")
            return
        }

        var c = input[idx]
        if c == chars.ESCAPE {
            isParsing = true
        }
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
