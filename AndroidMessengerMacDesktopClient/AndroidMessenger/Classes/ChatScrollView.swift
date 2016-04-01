//
//  ChatScrollView.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 3/29/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa

class ChatScrollView: NSScrollView {
    
    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
        
        // Drawing code here.
    }
    
    override func scrollWheel(theEvent: NSEvent) {
        self.nextResponder?.scrollWheel(theEvent)
    }
}
