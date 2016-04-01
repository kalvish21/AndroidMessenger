//
//  ChatMessageCell.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 3/23/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa

class ChatMessageCell: NSTableCellView {

    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet var chatTextField: NSTextView!
    @IBOutlet weak var descriptionLabel: NSTextField!
    var is_sending_message: Bool = false
    
    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
        
        // Drawing code here.
        self.chatTextField.backgroundColor = NSColor.clearColor()
        self.scrollView.backgroundColor = NSColor.clearColor()
        self.scrollView.borderType = .NoBorder
        
        self.chatTextField.font = NSFont.systemFontOfSize(13)
        self.chatTextField.textColor = NSColor.blackColor()
        
        if (is_sending_message) {
            NSColor.NSColorFromRGB(0xdeeff5).set()
            NSRectFill(self.bounds)
        } else {
            NSColor.whiteColor().set()
            NSRectFill(self.bounds)
        }
    }
}
