//
//  NSImage-Extension.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 8/21/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa
import Foundation
import AsyncImageDownloaderOSX

extension NSImageView {
    func loadImageFromUrl(url: String) {
        let image: NSImage? = NSImage.loadImageForUrl(url)
        if image != nil {
            self.wantsLayer = true
            self.layer!.borderColor = NSColor.blueColor().CGColor
            self.image = image
            return
        }
        
        // Download if the image was not cached
        AsyncImageDownloader.init(mediaURL: url, successBlock: { (image) in
            image.saveImageInCache(url)
            self.image = image
            }, failBlock: { (error) in
                NSLog("%@", error)
        }).startDownload()
    }
}

