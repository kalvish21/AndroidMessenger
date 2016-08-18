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
    
    static func NSColorFromHex(hexValue: String) -> NSColor {
        var result : NSColor? = nil
        var colorCode : UInt32 = 0
        var redByte, greenByte, blueByte : UInt8
        
        // these two lines are for web color strings that start with a #
        // -- as in #ABCDEF; remove if you don't have # in the string
        let index1 = hexValue.endIndex.advancedBy(-6)
        let substring1 = hexValue.substringFromIndex(index1)
        
        let scanner = NSScanner(string: substring1)
        let success = scanner.scanHexInt(&colorCode)
        
        if success == true {
            redByte = UInt8.init(truncatingBitPattern: (colorCode >> 16))
            greenByte = UInt8.init(truncatingBitPattern: (colorCode >> 8))
            blueByte = UInt8.init(truncatingBitPattern: colorCode) // masks off high bits
            
            result = NSColor(calibratedRed: CGFloat(redByte) / 0xff, green: CGFloat(greenByte) / 0xff, blue: CGFloat(blueByte) / 0xff, alpha: 1.0)
        }
        return result!
    }
}
