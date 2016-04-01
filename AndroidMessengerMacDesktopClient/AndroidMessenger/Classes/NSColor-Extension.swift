//
//  NSColor-Extension.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 3/26/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Foundation
import Cocoa

extension NSColor
{
    static func NSColorFromRGB(rgbValue: UInt) -> NSColor {
        return NSColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}
