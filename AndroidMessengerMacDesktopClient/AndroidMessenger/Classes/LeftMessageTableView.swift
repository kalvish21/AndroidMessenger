//
//  LeftMessageTableView.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 4/3/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa

class LeftMessageTableView: NSTableView {

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        // Drawing code here.
    }
    
    override func keyDown(theEvent: NSEvent) {
        let keyCode = theEvent.keyCode
        if Int(keyCode) == 48 && self.nextKeyView != nil {
            self.nextKeyView!.becomeFirstResponder()
        } else {
            return super.keyDown(theEvent)
        }
    }
}
