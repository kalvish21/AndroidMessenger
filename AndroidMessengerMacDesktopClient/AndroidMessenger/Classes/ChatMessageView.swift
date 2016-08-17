//
//  ChatMessageEventView.swift
//  Hangover
//
//  Created by Peter Sobot on 6/11/15.
//  Copyright © 2015 Peter Sobot. All rights reserved.
//

import Cocoa

class ChatMessageView : NSView {
    enum Orientation {
        case Left
        case Right
    }

    var string: NSAttributedString?
    var textLabel: NSTextField!
    
    var dateString: NSAttributedString?
    var timeLabel: NSTextField!
    
    var backgroundView: NSImageView!

    var orientation: Orientation = .Left
    static let font = NSFont.systemFontOfSize(NSFont.systemFontSize())

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        backgroundView = NSImageView(frame: NSZeroRect)
        backgroundView.imageScaling = .ScaleAxesIndependently
        backgroundView.image = NSImage(named: "gray_bubble_left")
        addSubview(backgroundView)
        
        timeLabel = NSTextField(frame: NSZeroRect)
        timeLabel.backgroundColor = NSColor.clearColor()
        timeLabel.textColor = NSColor.blackColor()
        timeLabel.bezeled = false
        timeLabel.bordered = false
        timeLabel.backgroundColor = NSColor.blackColor()
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
        textLabel.backgroundColor = NSColor.clearColor()
        textLabel.allowsEditingTextAttributes = true
        textLabel.selectable = true
        addSubview(textLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configureWithText(msg: NSManagedObject, orientation: Orientation) {
        self.orientation = orientation
        self.string = TextMapper.attributedStringForText(msg.valueForKey("msg") as! String, date: false)
        textLabel.attributedStringValue = self.string!
        backgroundView.image = NSImage(named: orientation == .Right ? "gray_bubble_right" : "gray_bubble_left")
        
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
            var backgroundFrame = NSMakeRect(frame.origin.x, 20, frame.size.width, frame.size.height - ChatMessageView.TimeHeight)

            backgroundFrame.size.width *= ChatMessageView.WidthPercentage

            let textMaxWidth = ChatMessageView.widthOfText(backgroundWidth: backgroundFrame.size.width)
            let textSize = ChatMessageView.textSizeInWidth(self.textLabel.attributedStringValue, width: textMaxWidth)
            let dateSize = ChatMessageView.textSizeInWidth(self.timeLabel.attributedStringValue, width: textMaxWidth)

            backgroundFrame.size.width = ChatMessageView.widthOfBackground(textWidth: textSize.width)

            switch (orientation) {
            case .Left:
                backgroundFrame.origin.x = frame.origin.x
            case .Right:
                backgroundFrame.origin.x = frame.size.width - backgroundFrame.size.width
            }
            
            backgroundView.frame = backgroundFrame
            
            switch (orientation) {
            case .Left:
                textLabel.frame = NSRect(
                    x: backgroundView.frame.origin.x + ChatMessageView.TextPointySideBorder,
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