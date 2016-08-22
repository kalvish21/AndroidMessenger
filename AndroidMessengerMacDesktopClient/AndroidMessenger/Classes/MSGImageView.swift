//
//  MSGImageView.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 8/21/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa
import Foundation


class MSGImageView: NSImageView {
    var url: String!
    
    override func mouseDown(theEvent: NSEvent) {
        let count = theEvent.clickCount
        
        if count > 1 {
            let urlFilePath = NSImage.pathForUrl(url)
            NSWorkspace.sharedWorkspace().openURL(urlFilePath)
        }
    }
}
