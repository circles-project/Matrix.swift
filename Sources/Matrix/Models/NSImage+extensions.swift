//
//  NSImage+extensions.swift
//  
//
//  Created by Charles Wright on 10/27/22.
//

import Foundation

#if os(macOS)

import AppKit

extension NSImage {
    // https://stackoverflow.com/questions/11949250/how-to-resize-nsimage/42915296#42915296
    public func downscale(to maxSize: CGSize) -> NSImage? {
        if let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(maxSize.width), pixelsHigh: Int(maxSize.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) {
            bitmapRep.size = maxSize
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
            NSGraphicsContext.current?.imageInterpolation = .none
            draw(in: NSRect(x: 0, y: 0, width: maxSize.width, height: maxSize.height), from: .zero, operation: .copy, fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()

            let resizedImage = NSImage(size: maxSize)
            resizedImage.addRepresentation(bitmapRep)
            return resizedImage
        }

        return nil
    }
    
    public func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let cgImg = self.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return nil
        }
        return NSBitmapImageRep(cgImage: cgImg).representation(using: .jpeg, properties: [.compressionFactor:compressionQuality])
    }
}

// make note regarding why cannot implement codable (requires subclassing, which subclessing NSImage also has its issues) (also for uiimage?) also consider using the jpeg data representation for data store?
extension NSImage: Encodable {
    public func encode(to encoder: Encoder) throws {
        if let data = self.tiffRepresentation {
            try data.encode(to: encoder)
        }
    }
}

#endif
