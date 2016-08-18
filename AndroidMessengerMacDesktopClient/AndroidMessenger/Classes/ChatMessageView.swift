//
//  ChatMessageEventView.swift
//  Hangover
//
//  Created by Peter Sobot on 6/11/15.
//  Copyright © 2015 Peter Sobot. All rights reserved.
//

import Cocoa
import QuartzCore

class ChatMessageView : NSView {
    enum Orientation {
        case Left
        case Right
    }

    var string: NSAttributedString?
    var textLabel: NSTextField!
    
    var dateString: NSAttributedString?
    var timeLabel: NSTextField!

    //var backgroundView: NSImageView!
    var backgroundView: NSView!

    var orientation: Orientation = .Left
    static let font = NSFont.systemFontOfSize(NSFont.systemFontSize())
    
    let messagesBlue = "4e69a2"
    let messagesGray = "2f4779"

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        backgroundView = NSView(frame: NSZeroRect)
        backgroundView.wantsLayer = true
        backgroundView.layer!.cornerRadius = 5
        backgroundView.layer!.backgroundColor = NSColor.NSColorFromHex(messagesGray).CGColor
        addSubview(backgroundView)
        
        timeLabel = NSTextField(frame: NSZeroRect)
        timeLabel.backgroundColor = NSColor.clearColor()
        timeLabel.textColor = NSColor.blackColor()
        timeLabel.bezeled = false
        timeLabel.bordered = false
        timeLabel.editable = false
        timeLabel.drawsBackground = false
        timeLabel.allowsEditingTextAttributes = true
        timeLabel.selectable = false
        addSubview(timeLabel)

        textLabel = NSTextField(frame: NSZeroRect)
        textLabel.bezeled = false
        textLabel.bordered = false
        textLabel.editable = false
        textLabel.drawsBackground = false
        textLabel.bordered = false
        textLabel.allowsEditingTextAttributes = true
        textLabel.selectable = true
        textLabel.wantsLayer = true
        textLabel.textColor = NSColor.whiteColor()
        textLabel.layer!.backgroundColor = NSColor.clearColor().CGColor
        addSubview(textLabel, positioned: .Above, relativeTo: backgroundView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configureWithText(msg: NSManagedObject, orientation: Orientation) {
        self.orientation = orientation
        self.string = TextMapper.attributedStringForText(msg.valueForKey("msg") as! String, date: false)
        textLabel.attributedStringValue = self.string!

        self.dateString = TextMapper.attributedStringForText((msg.valueForKey("time") as! NSDate).convertToStringDate("EEEE, MMM d, yyyy h:mm a"), date: true)
        
        if (msg.valueForKey("pending") as? Bool == true) {
            self.dateString = TextMapper.attributedStringForText("pending", date: true)
        } else if (msg.valueForKey("error") as? Bool == true) {
            self.dateString = TextMapper.attributedStringForText("failed", date: true)
        }
        timeLabel.attributedStringValue = self.dateString!
    }

    static let WidthPercentage: CGFloat = 0.75
    static let TextPointySideBorder: CGFloat = 12
    static let TextRoundSideBorder: CGFloat = 8
    static let TextTopBorder: CGFloat = 4
    static let TextBottomBorder: CGFloat = 4
    static let VerticalTextPadding: CGFloat = 4
    static let HorizontalTextMeasurementPadding: CGFloat = 5
    static let TimeHeight: CGFloat = 40

    override var frame: NSRect {
        didSet {
            let paddingEdges: CGFloat = 5
            var backgroundFrame = NSMakeRect(frame.origin.x + paddingEdges, 20, frame.size.width, frame.size.height - ChatMessageView.TimeHeight + 2)
            backgroundFrame.size.width *= ChatMessageView.WidthPercentage

            let textMaxWidth = ChatMessageView.widthOfText(backgroundWidth: backgroundFrame.size.width)
            let textSize = ChatMessageView.textSizeInWidth(self.textLabel.attributedStringValue, width: textMaxWidth)
            let dateSize = ChatMessageView.textSizeInWidth(self.timeLabel.attributedStringValue, width: textMaxWidth)

            backgroundFrame.size.width = ChatMessageView.widthOfBackground(textWidth: textSize.width)

            switch (orientation) {
            case .Left:
                backgroundFrame.origin.x = frame.origin.x + paddingEdges
                
                backgroundView.layer!.backgroundColor = NSColor.NSColorFromHex(messagesBlue).CGColor
                textLabel.layer!.backgroundColor = NSColor.NSColorFromHex(messagesBlue).CGColor
                break

            case .Right:
                backgroundFrame.origin.x = frame.size.width - backgroundFrame.size.width - paddingEdges
                
                backgroundView.layer!.backgroundColor = NSColor.NSColorFromHex(messagesGray).CGColor
                textLabel.layer!.backgroundColor = NSColor.NSColorFromHex(messagesGray).CGColor
                break
            }
            
            backgroundView.frame = backgroundFrame
            
            switch (orientation) {
            case .Left:
                textLabel.frame = NSRect(
                    x: backgroundView.frame.origin.x + 5,
                    y: backgroundView.frame.origin.y + ChatMessageView.TextTopBorder - (ChatMessageView.VerticalTextPadding / 2),
                    width: textSize.width,
                    height: textSize.height + ChatMessageView.VerticalTextPadding / 2
                )
                
                timeLabel.frame = NSRect(
                    x: backgroundView.frame.origin.x + 2,
                    y: backgroundView.frame.origin.y + ChatMessageView.TextTopBorder - (ChatMessageView.VerticalTextPadding / 2) - 18,
                    width: dateSize.width,
                    height: 15
                )
                
            case .Right:
                backgroundView.frame.origin.y = backgroundView.frame.origin.y + 10
                textLabel.frame = NSRect(
                    x: backgroundView.frame.origin.x + ChatMessageView.TextRoundSideBorder,
                    y: backgroundView.frame.origin.y + ChatMessageView.TextTopBorder - (ChatMessageView.VerticalTextPadding / 2),
                    width: textSize.width,
                    height: textSize.height + ChatMessageView.VerticalTextPadding / 2
                )
                
                timeLabel.frame = NSRect(
                    x: frame.size.width - dateSize.width - 5,
                    y: backgroundView.frame.origin.y + ChatMessageView.TextTopBorder - (ChatMessageView.VerticalTextPadding / 2) - 18,
                    width: dateSize.width,
                    height: 15
                )
            }
        }
    }

    class func widthOfText(backgroundWidth backgroundWidth: CGFloat) -> CGFloat {
        return backgroundWidth
            - ChatMessageView.TextRoundSideBorder
            - ChatMessageView.TextPointySideBorder
    }

    class func widthOfBackground(textWidth textWidth: CGFloat) -> CGFloat {
        return textWidth
            + ChatMessageView.TextRoundSideBorder
            + ChatMessageView.TextPointySideBorder
    }

    class func textSizeInWidth(text: NSAttributedString, width: CGFloat) -> CGSize {
        var size = text.boundingRectWithSize(
            NSMakeSize(width, 0),
            options: [
                NSStringDrawingOptions.UsesLineFragmentOrigin,
                NSStringDrawingOptions.UsesFontLeading
            ]
        ).size
        size.width += HorizontalTextMeasurementPadding
        return size
    }

    class func heightForContainerWidth(text: NSAttributedString, width: CGFloat) -> CGFloat {
        let size = textSizeInWidth(text, width: widthOfText(backgroundWidth: (width * WidthPercentage)))
        let height = size.height + TimeHeight + TextTopBorder + TextBottomBorder
        return height
    }
}