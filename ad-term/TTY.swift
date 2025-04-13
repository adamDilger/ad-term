//
//  TTY.swift
//  ad-term-cli
//
//  Created by Adam Dilger on 16/7/2024.
//

import Foundation
import AppKit
import term

public class TTY {
    var task: Process
    let slaveFile: FileHandle
    public let masterFile: FileHandle
    let callRender: () -> ()
    
    var ws: winsize
    
    private let terminal: TTerminal;
    
    var masterFD = -1
    
    public init(_ terminal: TTerminal, callRender: @escaping () -> ()) {
        self.terminal = terminal;
        self.task = Process()
        self.callRender = callRender
        
        var temp = Array<CChar>(repeating: 0, count: Int(PATH_MAX))
        var masterFD = Int32(-1)
        var slaveFD = Int32(-1)
        
        self.ws = winsize(
            ws_row: UInt16(terminal.HEIGHT),
            ws_col: UInt16(terminal.WIDTH),
            ws_xpixel: 1000,
            ws_ypixel: 1000
        )
        
        guard openpty(&masterFD, &slaveFD, &temp, nil, &ws) != -1 else {
            fatalError("failed to open pty")
        }
        
        self.masterFile = FileHandle.init(fileDescriptor: masterFD)
        self.slaveFile = FileHandle.init(fileDescriptor: slaveFD)
        
        self.task.executableURL = URL(fileURLWithPath: "/usr/bin/login")
        self.task.arguments = ["-fpq", "adamdilger", "/bin/bash"]
        self.task.standardOutput = slaveFile
        self.task.standardInput = slaveFile
        self.task.standardError = slaveFile
    }
    
    func resize(width: Int, height: Int) {
        self.ws.ws_col = UInt16(width)
        self.ws.ws_row = UInt16(height)
        
        let res = ioctl(self.masterFile.fileDescriptor, TIOCSWINSZ, &self.ws);
        terminal.resize(width: width, height: height)
        print("RES: \(res)")
    }
    
    public func run() {
        masterFile.readabilityHandler = { handler in
            self.terminal.parseIncomingLines(handler.availableData)
            self.callRender();

//            print("----------------------------------------------------")
//            for c in handler.availableData.enumerated() {
//                print("\(Character(UnicodeScalar(c.element)))", terminator: "")
//            }
//            print("\n----------------------------------------------------")
        }
        
        do {
            try self.task.run()
        } catch {
            print("Something went wrong.\(error)\n")
        }
    }
    
    public func keyDown(_ characters: String) {
        self.masterFile.write(characters.data(using: .utf8)!)
    }
}
