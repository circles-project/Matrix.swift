//
//  Matrix+Image.swift
//
//
//  Created by Charles Wright on 9/28/23.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Matrix {
    public class Image: ObservableObject {
        
        public enum Source {
            case local
            case remote(mImageContent)
        }
        
        public enum Status {
            case notLoaded
            case loading(Task<Void,Swift.Error>)
            case loaded(Data)
            case failed(String)
        }
        
        @Published private(set) public var state: (Source,Status)
        private var session: Session
        
        public init(data: Data, source: Source, session: Session) {
            self.state = (source, .loaded(data))
            self.session = session
        }
        
        public init(content: mImageContent, session: Session) {
            let source: Source = .remote(content)
            self.state = (source, .notLoaded)
            self.session = session
        }
        
        public func download() async throws {
            let (source, status) = self.state
            
            switch self.state {
            
            case (.local, _):
                Matrix.logger.warning("Can't download a local image")
                
            case (.remote(let content), .notLoaded),
                 (.remote(let content), .failed):
                let task: Task<Void, Swift.Error> = Task {
                    if let file = content.file {
                        let data = try await session.downloadAndDecryptData(file)
                        await MainActor.run {
                            self.state = (source, .loaded(data))
                        }
                    } else if let mxc = content.url {
                        let data = try await session.downloadData(mxc: mxc)
                        await MainActor.run {
                            self.state = (source, .loaded(data))
                        }
                    } else {
                        Matrix.logger.error("Can't download an image with no encrypted file and no URL")
                        await MainActor.run {
                            self.state = (source, .failed("Invalid image content: No encrypted file and no URL"))
                        }
                    }
                }
                await MainActor.run {
                    self.state = (source, .loading(task))
                }
                
            case (.remote, .loading(let task)):
                Matrix.logger.debug("Already downloading this image...")
                await task.result
                
            case (.remote, .loaded):
                Matrix.logger.warning("Already downloaded this image")
            }

        }
        
        public var data: Data? {
            if case let (_, .loaded(data)) = self.state {
                return data
            } else {
                return nil
            }
        }
        
        public var source: Source {
            let (source, _) = self.state
            return source
        }

        #if canImport(UIKit)
        public var uiImage: UIImage? {
            if let data = self.data {
                return UIImage(data: data)
            } else {
                return nil
            }
        }
        //public lazy var image: SwiftUI.Image = SwiftUI.Image(uiImage: self.uiImage ?? UIImage())
        #elseif canImport(AppKit)
        public var nsImage: NSImage? {
            if let data = self.data {
                return NSImage(data: data)
            } else {
                return nil
            }
        }
        //public lazy var image: SwiftUI.Image = SwiftUI.Image(nsImage: self.nsImage ?? NSImage())
        #endif
    }
}
