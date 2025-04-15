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

    var terminal: TTerminal!
    var tty: TTY!

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

        guard let mtkView = view as? MTKView else {
            print("View attached to GameViewController is not an MTKView")
            return
        }

        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }

        mtkView.device = defaultDevice

        let _a = mtkView.drawableSize.width / CGFloat(fontWidth)
        let _b = mtkView.drawableSize.height / CGFloat(fontHeight)
        let _c = Int(floor(_a))
        let _d = Int(floor(_b))

        let WIDTH = _c
        let HEIGHT = _d

        let buf = Data()
        terminal = TTerminal(buffer: buf, reporter: { s in
            print("Reporting: \(s)")
            self.tty.keyDown(s)
        })
        terminal.resize(width: WIDTH, height: HEIGHT)

        tty = TTY(terminal, callRender: { self.renderer.tick() })

        guard let newRenderer = Renderer(metalKitView: mtkView, terminal: terminal, tty: tty) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer
        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer

        tty.run()
    }

    @objc func terminalDataUpdate(_: Notification) {
        if renderer == nil { return }
        renderer.tick()
    }

    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)

        switch event.keyCode {
        case /* KEY_UP */ 126: tty.keyDown("\u{1b}[A"); return;
        case /* KEY_DOWN */ 125: tty.keyDown("\u{1b}[B"); return;
        case /* KEY_LEFT */ 123: tty.keyDown("\u{1b}[D"); return;
        case /* KEY_RIGHT */ 124: tty.keyDown("\u{1b}[C"); return;
        default: break
        }

        if let c: String = event.characters {
            tty.keyDown(c)
        }
    }

    override var acceptsFirstResponder: Bool {
        true
    }
}
