//
//  TTY.swift
//  ad-term-cli
//
//  Created by Adam Dilger on 16/7/2024.
//

import Foundation
import Darwin
import AppKit

class TTY {
    var task: Process?
    var slaveFile: FileHandle?
    var masterFile: FileHandle?
    
//    var buffer: Data;
//    var lines: Array<line>;
    var terminal: Terminal;

    init(_ terminal: Terminal) {
        self.terminal = terminal;
        
        self.task = Process()
        
        var temp = Array<CChar>(repeating: 0, count: Int(PATH_MAX))
        var masterFD = Int32(-1)
        var slaveFD = Int32(-1)
        
        var ws = winsize(ws_row: UInt16(HEIGHT), ws_col: UInt16(WIDTH), ws_xpixel: 1000, ws_ypixel: 1000)
        
        guard openpty(&masterFD, &slaveFD, &temp, nil, &ws) != -1 else {
            fatalError("failed to open pty")
        }
        
        self.masterFile = FileHandle.init(fileDescriptor: masterFD)
        self.slaveFile = FileHandle.init(fileDescriptor: slaveFD)
        
        self.task!.executableURL = URL(fileURLWithPath: "/bin/bash")
        self.task!.arguments = ["-i"]; //, "-c"]; , "vi ~/.bashrc"]
        self.task!.standardOutput = slaveFile
        self.task!.standardInput = slaveFile
        self.task!.standardError = slaveFile
    }
    
    func newLine(at: Int) {
        self.terminal.lines.append(line(start: at + 1, end: at + 1))
    }
    
    func run() {
        let tmp = FileHandle.init(forUpdatingAtPath: "/Users/adamdilger/helloworld.txt");
        
        self.masterFile!.readabilityHandler = { handler in
            let cur = self.terminal.buffer.count
             
            let data = handler.availableData;
            
            tmp!.write(data);
            do {
                try tmp!.synchronize()
            } catch {
                print(error);
            }
            
            // print(String(decoding: data, as: UTF8.self))
            
            self.terminal.buffer.append(data)
//            let r = cur..<self.terminal.buffer.count;
            
            // let a = String(decoding: self.buffer.subdata(in: r), as: UTF8.self)
            // print(a, terminator: "")
            
            // parse output to determine lines

//            for i in r {
//                self.terminal.lines[self.terminal.lines.count - 1].end += 1;
//                let b = self.terminal.buffer[i];
//                if (self.terminal.buffer[i] == newline) {
//                    self.newLine(at: i);
//                }
//                else if (b == backspace) {
//                    self.newLine(at: i);
//                }
//            }
            
            self.terminal.draw()
        }

        do {
            try self.task!.run()
        } catch {
            print("Something went wrong.\(error)\n")
        }
    }
    
    func keyDown(event: NSEvent) {
        let c = event.characters!;
        self.masterFile!.write(c.data(using: .utf8)!)
    }
}
