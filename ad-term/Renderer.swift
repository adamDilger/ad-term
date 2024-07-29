//
//  Renderer.swift
//  ad-term
//
//  Created by Adam Dilger on 24/7/2024.
//
import Metal
import MetalKit
import simd

struct Vertex {
    var position: simd_float2
    var texCoord: simd_float2
    var bgColor: simd_float3
    var fgColor: simd_float3
}

class Renderer: NSObject, MTKViewDelegate {
    var helloworld = 0;
    
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    
    var vertexDescriptor: MTLVertexDescriptor
    
    var library: MTLLibrary
    var vertexFunction: MTLFunction
    var fragmentFunction: MTLFunction
    
    var renderPipelineState: MTLRenderPipelineState?
    
    var vertexBuffer: MTLBuffer
    var indexBuffer: MTLBuffer
    
//     var colorTexture: MTLTexture?
    var fontTexture: MTLTexture?
    
    var vertices: [Vertex] = []
    var indices: [ushort] = []
    
    init?(metalKitView: MTKView, _ cells: inout [Cell]) {
        //Device and command queue
        self.device = metalKitView.device!
        self.commandQueue = self.device.makeCommandQueue()!
        
        //Vertex descriptor
        vertexDescriptor = MTLVertexDescriptor()
        
        vertexDescriptor.layouts[30].stride = MemoryLayout<Vertex>.stride
        vertexDescriptor.layouts[30].stepRate = 1
        vertexDescriptor.layouts[30].stepFunction = MTLVertexStepFunction.perVertex
        
        vertexDescriptor.attributes[0].format = MTLVertexFormat.float2
        vertexDescriptor.attributes[0].offset = MemoryLayout.offset(of: \Vertex.position)!
        vertexDescriptor.attributes[0].bufferIndex = 30
        
        vertexDescriptor.attributes[1].format = MTLVertexFormat.float2
        vertexDescriptor.attributes[1].offset = MemoryLayout.offset(of: \Vertex.texCoord)!
        vertexDescriptor.attributes[1].bufferIndex = 30
        
        vertexDescriptor.attributes[2].format = MTLVertexFormat.float3
        vertexDescriptor.attributes[2].offset = MemoryLayout.offset(of: \Vertex.bgColor)!
        vertexDescriptor.attributes[2].bufferIndex = 30
        
        vertexDescriptor.attributes[3].format = MTLVertexFormat.float3
        vertexDescriptor.attributes[3].offset = MemoryLayout.offset(of: \Vertex.fgColor)!
        vertexDescriptor.attributes[3].bufferIndex = 30

        // Library
        self.library = device.makeDefaultLibrary()!
        self.vertexFunction = library.makeFunction(name: "vertexFunction")!
        self.fragmentFunction = library.makeFunction(name: "fragmentFunction")!
        
        //Render pipeline descriptor
        let renderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineStateDescriptor.vertexFunction = vertexFunction
        renderPipelineStateDescriptor.fragmentFunction = fragmentFunction
        renderPipelineStateDescriptor.vertexDescriptor = vertexDescriptor
        renderPipelineStateDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        do {
            self.renderPipelineState = try self.device.makeRenderPipelineState(descriptor: renderPipelineStateDescriptor)
        } catch {
            print("Failed to create render pipeline state")
        }
        
        self.vertices = []
        self.indices = []
        fill(&self.vertices, &self.indices, &cells, cursor: point(x: 0, y: 0));
        
        self.vertexBuffer = self.device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride, options: MTLResourceOptions.storageModeShared)!
        self.indexBuffer = self.device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<ushort>.stride, options: MTLResourceOptions.storageModeShared)!


        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: fontWidth * 16,
            height: fontHeight * 16,
            mipmapped: true)
        self.fontTexture = device.makeTexture(descriptor: textureDescriptor)!
        
        for i in 32..<127 {
            GenerateGlyph(texture: self.fontTexture!, char: Character(UnicodeScalar(i)!))
        }
        
        super.init()
    }
    
    func draw(in view: MTKView) {
        //Create command buffer
        let commandBuffer = self.commandQueue.makeCommandBuffer()!
        
        // Retrieve render pass descriptor and change the background color
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
        
        if (self.vertices.count > 0) {
            // Create render command encoder
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            
            // Bind render pipeline state
            renderEncoder.setRenderPipelineState(self.renderPipelineState!)
            
            // Bind vertex buffer
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 30)
            
            // Bind color texture
            renderEncoder.setFragmentTexture(fontTexture, index: 0)
            
            // Render
            renderEncoder.drawIndexedPrimitives(
                type: MTLPrimitiveType.triangle,
                indexCount: WIDTH * HEIGHT * 6,
                indexType: MTLIndexType.uint16,
                indexBuffer: indexBuffer,
                indexBufferOffset: 0)
            
            //End encoding
            renderEncoder.endEncoding()
        }
        
        //Retrieve drawable and present it to the screen
        let drawable = view.currentDrawable!
        commandBuffer.present(drawable)
        
        //Send our commands to the GPU
        commandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let _a = size.width / CGFloat(fontWidth);
        let _b = size.height / CGFloat(fontHeight);
        let _c = Int(floor(_a))
        let _d = Int(floor(_b))

        print("new WIDTH \(_c)");
        print("new HEIGHT \(_d)");
    }
    
    func tick(terminal: Terminal) {
        self.vertices = [];
        self.indices = [];
        fill(&self.vertices, &self.indices, &terminal.cells, cursor: terminal.cursor);
        self.vertexBuffer.contents().copyMemory(from: &self.vertices, byteCount: vertices.count * MemoryLayout<Vertex>.stride)
    }
}
    
let H: Float = 16
let W: Float = 16
func fill(_ vertices: inout [Vertex], _ indices: inout [ushort], _ cells: inout [Cell], cursor: point) {
    for i in 0..<HEIGHT {
        let cursorInRow = cursor.y == i;
        
        let iOffset = (i * WIDTH)
        for j in 0..<WIDTH {
            let isCursor = cursorInRow && cursor.x == j;
            
            let idx = (j + iOffset) % cells.count;
            let cell = cells[idx];
            
            let v_idx: UInt16 = UInt16(idx * 4)
            indices.append(contentsOf: [
                v_idx, v_idx + 1, v_idx + 2,
                v_idx, v_idx + 2, v_idx + 3
            ])
            
            let x_0 = ((Float(j) / Float(WIDTH)) - 0.5) * 2;
            let x_1 = ((Float(j + 1) / Float(WIDTH)) - 0.5) * 2;
            let y_0 = (((Float(i) / Float(HEIGHT)) - 0.5) * -1) * 2;
            let y_1 = (((Float(i + 1) / Float(HEIGHT)) - 0.5) * -1) * 2;
            
            let cellChar = cell.char ?? " "
            let cellCharAscii = cellChar.asciiValue ?? 0;
            
            let x_A = cellCharAscii % 16;
            let y_A = cellCharAscii / 16;
            
            let cx0 = (Float(x_A) / W)
            let cx1 = (Float(x_A + 1) / W)
            let cy0 = (Float(y_A) / H)
            let cy1 = (Float(y_A + 1) / H)
            
            var bgColor = colours[cell.bgColor ?? 40] ?? Black
            var fgColor = colours[cell.fgColor ?? 37] ?? White
            
            if cell.inverted || isCursor {
                let tmp = bgColor;
                bgColor = fgColor;
                fgColor = tmp;
            }

            vertices.append(Vertex(position: simd_float2( x_0,    y_1), texCoord: simd_float2(cx0, cy1), bgColor: bgColor, fgColor: fgColor));
            vertices.append(Vertex(position: simd_float2( x_1,    y_1), texCoord: simd_float2(cx1, cy1), bgColor: bgColor, fgColor: fgColor));
            vertices.append(Vertex(position: simd_float2( x_1,    y_0), texCoord: simd_float2(cx1, cy0), bgColor: bgColor, fgColor: fgColor));
            vertices.append(Vertex(position: simd_float2( x_0,    y_0), texCoord: simd_float2(cx0, cy0), bgColor: bgColor, fgColor: fgColor));
        }
    }
}

let Black    = simd_float3(0.25, 0.25, 0.25);
let Red    = simd_float3(1, 0.25, 0.25);
let Green    = simd_float3(0.25, 1, 0.25);
let Yellow    = simd_float3(1, 1, 0.25);
let Blue    = simd_float3(0.25, 0.25, 1);
let Magenta    = simd_float3(1, 0.25, 1);
let Cyan    = simd_float3(0.25, 1, 1);
let White    = simd_float3(1, 1, 1);

//let Black = simd_float3(0, 0, 0);
//let Red    = simd_float3(0.5, 0, 0);
//let Green    = simd_float3(0, 0.5, 0);
//let Yellow    = simd_float3(0.5, 0.25, 0);
//let Blue = simd_float3(0, 0, 0.5);
//let Magenta    = simd_float3(0.5, 0, 0.5);
//let Cyan = simd_float3(0, 0.5, 0.5);
//let White    = simd_float3(0.5, 0.5, 0.5);

let colours: [UInt16 : simd_float3] = [
    30: Black,
    31: Red,
    32: Green,
    33: Yellow,
    34: Blue,
    35: Magenta,
    36: Cyan,
    37: White,
    40: Black,
    41: Red,
    42: Green,
    43: Yellow,
    44: Blue,
    45: Magenta,
    46: Cyan,
    47: White,
]
