//
//  TextMapper.swift
//  Hangover
//
//  Created by Peter Sobot on 6/28/15.
//  Copyright © 2015 Peter Sobot. All rights reserved.
//

import Cocoa

class TextMapper {
    class func attributedStringForText(text: String, date: Bool) -> NSAttributedString {
        let attrString = NSMutableAttributedString(string: text)

        let style = NSMutableParagraphStyle()
        style.lineBreakMode = NSLineBreakMode.ByWordWrapping

        let linkDetector = try! NSDataDetector(types: NSTextCheckingType.Link.rawValue)
        for match in linkDetector.matchesInString(text, options: [], range: NSMakeRange(0, text.characters.count)) {
            if let url = match.URL {
                attrString.addAttribute(NSLinkAttributeName, value: url, range: match.range)
                attrString.addAttribute(NSForegroundColorAttributeName, value: NSColor.blueColor(), range: match.range)
                attrString.addAttribute(NSUnderlineStyleAttributeName, value: NSNumber(integer: NSUnderlineStyle.StyleSingle.rawValue), range: match.range)
            }
        }

        if !date {
            attrString.addAttribute(NSFontAttributeName, value: NSFont.systemFontOfSize(12), range: NSMakeRange(0, attrString.length))
        } else {
            attrString.addAttribute(NSFontAttributeName, value: NSFont.systemFontOfSize(9), range: NSMakeRange(0, attrString.length))
        }
        attrString.addAttribute(NSParagraphStyleAttributeName, value: style, range: NSMakeRange(0, attrString.length))
        return attrString
    }
}
