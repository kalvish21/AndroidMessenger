//
//  MessageTextField.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 3/30/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa

class MessageTextField: NSTextField {

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        // Drawing code here.
    }
    
    override var intrinsicContentSize:NSSize{
        if (self.cell == nil) {
            return super.intrinsicContentSize
        }
        
        self.preferredMaxLayoutWidth = self.frame.size.width
        let new_frame = NSMakeRect(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, CGFloat.max)
        let height = self.cell?.cellSizeForBounds(new_frame).height
        
        if (height! >= 50) {
            return NSMakeSize(self.frame.size.width, 50)
        }
        return NSMakeSize(self.frame.size.width, height!)
    }
}
