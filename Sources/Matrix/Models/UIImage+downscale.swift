//
//  UIImage+downscale.swift
//  
//
//  Created by Charles Wright on 10/27/22.
//

import Foundation

#if !os(macOS)
import UIKit

extension UIImage {
    public func downscale(to maxSize: CGSize) -> UIImage? {
        let height = self.size.height
        let width = self.size.width
        let MAX_HEIGHT = maxSize.height
        let MAX_WIDTH = maxSize.width
        print("DOWNSCALE\t h = \(height)\t w = \(width)")
        print("DOWNSCALE\t max h = \(MAX_HEIGHT)\t max w = \(MAX_WIDTH)")

        if height > MAX_HEIGHT || width > MAX_WIDTH {
            let aspectRatio = self.size.width / self.size.height
            print("DOWNSCALE\tAspect ratio = \(aspectRatio)")
            let scale = aspectRatio > 1
                ? MAX_WIDTH / self.size.width
                : MAX_HEIGHT / self.size.height
            print("DOWNSCALE\tScale = \(scale)")
            let newSize = CGSize(width: scale*self.size.width, height: scale*self.size.height)
            print("DOWNSCALE\tNew size = \(newSize)")
            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { (context) in
                self.draw(in: CGRect(origin: .zero, size: newSize))
            }
        } else {
            return nil
        }
    }
}

#endif
