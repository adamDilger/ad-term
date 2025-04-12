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
    let task: Process
    let slaveFile: FileHandle
    public let masterFile: FileHandle
    
    var ws: winsize
    
    private let terminal: TTerminal;
    
    var masterFD = -1
    
    public init(_ terminal: TTerminal) {
        self.terminal = terminal;
        self.task = Process()
        
        var temp = Array<CChar>(repeating: 0, count: Int(PATH_MAX))
        var masterFD = Int32(-1)
        var slaveFD = Int32(-1)
        
        self.ws = winsize(
            ws_row: terminal.HEIGHT,
            ws_col: terminal.WIDTH,
            ws_xpixel: 1000,
            ws_ypixel: 1000
        )
        
        guard openpty(&masterFD, &slaveFD, &temp, nil, &ws) != -1 else {
            fatalError("failed to open pty")
        }
        
        self.masterFile = FileHandle.init(fileDescriptor: masterFD)
        self.slaveFile = FileHandle.init(fileDescriptor: slaveFD)
        
        self.task.executableURL = URL(fileURLWithPath: "/bin/bash")
        self.task.arguments = ["-i"]; //, "-c"]; , "vi ~/.bashrc"]
        self.task.standardOutput = slaveFile
        self.task.standardInput = slaveFile
        self.task.standardError = slaveFile
    }
    
    func resize(width: UInt16, height: UInt16) {
        self.ws.ws_col = UInt16(width)
        self.ws.ws_row = UInt16(height)
        
        let res = ioctl(self.masterFile.fileDescriptor, TIOCSWINSZ, &self.ws);
        print("RES: \(res)")
    }
    
    public func run() {
        masterFile.readabilityHandler = { handler in
            self.terminal.parseIncomingLines(handler.availableData)
            self.terminal.draw()
            
            print("---")
            for i in 0..<Int(self.terminal.WIDTH) {
                if let c = self.terminal.cells[i].char {
                    print(Character(UnicodeScalar(Int(c))!), terminator: "")
                }
            }
            print("\n---")
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
