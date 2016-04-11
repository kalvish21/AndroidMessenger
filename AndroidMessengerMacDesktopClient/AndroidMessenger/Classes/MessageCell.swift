//
//  MessageCell.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 3/22/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa

class MessageCell: NSTableCellView {

    @IBOutlet weak var nameLabel: NSTextField!
    @IBOutlet weak var descriptionLabel: NSTextField!
    
    override var backgroundStyle: NSBackgroundStyle {
        didSet {
            if self.backgroundStyle == .Light {
                self.nameLabel.textColor = NSColor.blackColor()
                self.descriptionLabel.textColor = NSColor.NSColorFromRGB(0x9A9A9A)
            } else if self.backgroundStyle == .Dark {
                self.nameLabel.textColor = NSColor.whiteColor()
                self.descriptionLabel.textColor = NSColor.NSColorFromRGB(0xd6d6d6)
            }
        }
    }
}
