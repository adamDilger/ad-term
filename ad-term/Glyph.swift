//
//  Glyph.swift
//  ad-term
//
//  Created by Adam Dilger on 26/7/2024.
//

import Foundation
import CoreText
import GLKit
import AppKit

func GenerateGlyph(texture: MTLTexture, char: Character) {
    let mabstring = NSMutableAttributedString(string: String(char))
    mabstring.beginEditing()
    mabstring.addAttribute(.font, value: font, range: NSRange(location: 0, length: 1))
    mabstring.addAttribute(.foregroundColor, value: CGColor.white, range: NSRange(location: 0, length: 1))
    mabstring.endEditing()
    
    let rect = CGRect(origin: .zero, size: fontSize)
    
    var rawData = [UInt8](repeating: 0, count: Int(fontWidth * fontHeight * 4))
    let bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue)
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let bitsPerComponent = 8
    let bytesPerRow = fontWidth * 4
    let context = CGContext(data: &rawData, width: fontWidth, height: fontHeight, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: rgbColorSpace, bitmapInfo: bitmapInfo.rawValue)!
    
    let path = CGMutablePath()
    path.addRect(rect)
    
    let framesetter = CTFramesetterCreateWithAttributedString(mabstring)
    let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
    CTFrameDraw(frame, context)
    
    let providerRef = CGDataProvider(data: NSData(bytes: &rawData, length: rawData.count * MemoryLayout.size(ofValue: UInt8(0))))
    let renderingIntent =  CGColorRenderingIntent.defaultIntent
    let imageRef = CGImage(width: fontWidth, height: fontHeight, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow, space: rgbColorSpace, bitmapInfo: bitmapInfo, provider: providerRef!, decode: nil, shouldInterpolate: false, intent: renderingIntent)!

    writeCGImage(imageRef)
    
    //to MTLTexture
    let x = char.asciiValue! % 16
    let y = char.asciiValue! / 16;
    
    let region = MTLRegionMake2D(Int(x) * fontWidth, Int(y) * fontHeight, fontWidth, fontHeight)
    texture.replace(region: region, mipmapLevel: 0, withBytes: &rawData, bytesPerRow: imageRef.bytesPerRow)
}

@discardableResult func writeCGImage(_ image: CGImage) -> Bool {
    let destinationURL = URL(filePath: "/Users/adamdilger/helloworld.png")
    guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, kUTTypePNG, 1, nil) else { return false }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}

//let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: fontWidth, height: fontHeight, mipmapped: true)
//let device = MTLCreateSystemDefaultDevice()!
//let texture = device.makeTexture(descriptor: textureDescriptor)!

let font = CTFontCreateWithName("Menlo" as CFString, 20, nil)
let fontSize = getFontSize()
let fontWidth = Int(fontSize.width)
let fontHeight = Int(fontSize.height)
func getFontSize() -> CGSize {
    let mabstring = NSMutableAttributedString(string: "m")
    mabstring.beginEditing()
    mabstring.addAttribute(.font, value: font, range: NSRange(location: 0, length: 1))
    mabstring.endEditing()
    
    let framesetter = CTFramesetterCreateWithAttributedString(mabstring)
    let cgsize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, 1), nil, CGSize(), nil)
    
    return cgsize;
}
