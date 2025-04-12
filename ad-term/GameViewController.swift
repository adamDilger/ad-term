//
//  GameViewController.swift
//  ad-term
//
//  Created by Adam Dilger on 24/7/2024.
//

import Cocoa
import MetalKit
import term

class GameViewController: NSViewController {
    var renderer: Renderer!
    var mtkView: MTKView!

    var terminal: TTerminal!;
    var tty: TTY!;

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) {
            self.flagsChanged(with: $0)
            return $0
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            self.keyDown(with: $0)
            return $0
        }
        
        let nc = NotificationCenter.default
        nc.addObserver(
            self,
            selector: #selector(terminalDataUpdate(_:)),
            name: Notification.Name("TerminalDataUpdate"),
            object: nil
        )

        guard let mtkView = self.view as? MTKView else {
            print("View attached to GameViewController is not an MTKView")
            return
        }

        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }

        mtkView.device = defaultDevice

        let _a = mtkView.drawableSize.width / CGFloat(fontWidth);
        let _b = mtkView.drawableSize.height / CGFloat(fontHeight);
        let _c = Int(floor(_a))
        let _d = Int(floor(_b))

        let WIDTH = UInt16(_c);
        let HEIGHT = UInt16(_d);

        let buf = Data()
        self.terminal = TTerminal(buffer: buf)
        self.terminal.resize(width: WIDTH, height: HEIGHT)
        
        self.tty = TTY(terminal);

        guard let newRenderer = Renderer(metalKitView: mtkView, terminal: self.terminal) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer
        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer
        
        tty.run()
    }
    
    @objc func terminalDataUpdate(_ notification: Notification) {
        if renderer == nil { return; }
        renderer.tick();
    }
    
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        
        if let c: String = event.characters {
            self.tty.keyDown(c)
        }
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}
