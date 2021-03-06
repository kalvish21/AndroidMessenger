//
//  ChatMessageEventView.swift
//  Hangover
//
//  Created by Peter Sobot on 6/11/15.
//  Copyright © 2015 Peter Sobot. All rights reserved.
//

import Cocoa
import QuartzCore
import Alamofire

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
    var mmsView: NSView = NSView(frame: NSZeroRect)
    static var field = NSTextField(frame: NSZeroRect)
    
    var orientation: Orientation = .Left
    static let font = NSFont.systemFontOfSize(NSFont.systemFontSize())
    
    let messagesBlue = "1e85f3"
    let messagesGray = "e5e5ea"
    
    var message: Message!
    var msgHeight: CGFloat = 0.0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        backgroundView = NSView(frame: NSZeroRect)
        backgroundView.wantsLayer = true
        backgroundView.layer!.cornerRadius = 5
        backgroundView.layer!.backgroundColor = NSColor.NSColorFromHex(messagesGray).CGColor
        addSubview(backgroundView)
        
        mmsView = NSView(frame: NSZeroRect)
        mmsView.wantsLayer = true
        addSubview(mmsView)
        
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
        
        textLabel = ChatTextField(frame: NSZeroRect)
        textLabel.bezeled = false
        textLabel.bordered = false
        textLabel.editable = false
        textLabel.drawsBackground = false
        textLabel.bordered = false
        textLabel.allowsEditingTextAttributes = false
        textLabel.selectable = true
        textLabel.wantsLayer = true
        textLabel.refusesFirstResponder = true
        textLabel.textColor = NSColor.whiteColor()
        textLabel.layer!.backgroundColor = NSColor.clearColor().CGColor
        addSubview(textLabel, positioned: .Above, relativeTo: backgroundView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureWithText(msg: Message, orientation: Orientation) {
        self.message = msg
        self.orientation = orientation
        self.string = TextMapper.attributedStringForText(msg.valueForKey("msg") as! String, date: false)
        textLabel.attributedStringValue = self.string!
        
        self.dateString = TextMapper.attributedStringForText((msg.valueForKey("time") as! NSDate).convertToStringDate("EEEE, MMM d, yyyy h:mm a"), date: true)
        
        if (msg.valueForKey("pending") as? Bool == true) {
            self.dateString = TextMapper.attributedStringForText("pending", date: true)
            
            // See if message failed
            let objectId = msg.objectID
            let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(10 * Double(NSEC_PER_SEC)))
            dispatch_after(delayTime, dispatch_get_main_queue()) {
                let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
                let context = delegate.coreDataHandler.managedObjectContext
                
                let msg = context.objectWithID(objectId)
                var changed: Bool = false
                if msg.valueForKey("pending") as? Bool == true {
                    msg.setValue(false, forKey: "pending")
                    msg.setValue(true, forKey: "error")
                    changed = true
                }
                
                if !changed {
                    return
                }
                
                do {
                    // Save the context
                    try context.save()
                    delegate.coreDataHandler.managedObjectContext.performBlock({
                        do {
                            try delegate.coreDataHandler.managedObjectContext.save()
                        } catch {
                            fatalError("Failure to save context: \(error)")
                        }
                    })
                    
                    let userInfo: Dictionary<String, AnyObject> = ["thread_id": msg.valueForKey("thread_id") as! Int]
                    NSNotificationCenter.defaultCenter().postNotificationName(chatDataShouldRefresh, object: userInfo)
                    
                } catch let error as NSError {
                    NSLog("Unresolved error: %@, %@", error, error.userInfo)
                }
            }
            
        } else if (msg.valueForKey("error") as? Bool == true) {
            self.dateString = TextMapper.attributedStringForText("failed", date: true)
        }
        timeLabel.attributedStringValue = self.dateString!
    }
    
    func configureWithTextAndData(msg: Message, orientation: Orientation) {
        self.message = msg
        self.orientation = orientation
        self.string = TextMapper.attributedStringForText(msg.valueForKey("msg") as! String, date: false)
        textLabel.attributedStringValue = self.string!
        self.dateString = TextMapper.attributedStringForText((msg.valueForKey("time") as! NSDate).convertToStringDate("EEEE, MMM d, yyyy h:mm a"), date: true)
        
        var image_contenttype = 0
        if message.sms! == false && message.messageparts!.count > 0 {
            for part in 0...message.messageparts!.count-1{
                let dict = message.messageparts![part] as! MessagePart
                NSLog(dict.content_type!)
                switch(dict.content_type!) {
                case "image/jpeg", "image/jpg", "image/png", "image/gif", "image/bmp":
                    let imageview = MSGImageView(frame: NSMakeRect(0,CGFloat(image_contenttype * 150),150,150))
                    mmsView.addSubview(imageview)
                    imageview.imageScaling = .ScaleProportionallyDown
                    
                    let networking = NetworkingUtil()
                    let url = networking.getFullUrlPath("message/mms/file?uid=" + networking.generateUUID() + "&part_id=" + String(dict.id!))
                    NSLog(url)
                    imageview.url = url
                    imageview.loadImageFromUrl(url)
                    self.addSubview(mmsView)
                    image_contenttype += 1
                    
                    break
                    
                default:
                    break
                }
            }
            mmsView.frame = NSMakeRect(0,0,150,CGFloat(image_contenttype * 150))
            msgHeight += CGFloat(CGFloat(image_contenttype) * ChatMessageView.MMSHeight)
        }
        
        if (msg.valueForKey("pending") as? Bool == true) {
            self.dateString = TextMapper.attributedStringForText("pending", date: true)
            
            // See if message failed
            let objectId = msg.objectID
            let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(30 * Double(NSEC_PER_SEC)))
            dispatch_after(delayTime, dispatch_get_main_queue()) {
                let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
                let context = delegate.coreDataHandler.managedObjectContext
                
                let msg = context.objectWithID(objectId)
                var changed: Bool = false
                if msg.valueForKey("pending") as? Bool == true {
                    msg.setValue(false, forKey: "pending")
                    msg.setValue(true, forKey: "error")
                    changed = true
                }
                
                if !changed {
                    return
                }
                
                do {
                    // Save the context
                    try context.save()
                    delegate.coreDataHandler.managedObjectContext.performBlock({
                        do {
                            try delegate.coreDataHandler.managedObjectContext.save()
                        } catch {
                            fatalError("Failure to save context: \(error)")
                        }
                    })
                    
                    let userInfo: Dictionary<String, AnyObject> = ["thread_id": msg.valueForKey("thread_id") as! Int]
                    NSNotificationCenter.defaultCenter().postNotificationName(chatDataShouldRefresh, object: userInfo)
                    
                } catch let error as NSError {
                    NSLog("Unresolved error: %@, %@", error, error.userInfo)
                }
            }
            
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
    static let MMSHeight: CGFloat = 150
    
    var backgroundFrame: NSRect!
    
    override var frame: NSRect {
        didSet {
            let paddingEdges: CGFloat = 5
            backgroundFrame = NSMakeRect(frame.origin.x + paddingEdges, 20, frame.size.width, frame.size.height - ChatMessageView.TimeHeight + 2)
            backgroundFrame.size.width *= ChatMessageView.WidthPercentage
            NSLog("%f",frame.size.width)
            
            let textMaxWidth = ChatMessageView.widthOfText(backgroundWidth: backgroundFrame.size.width)
            let textSize = ChatMessageView.textSizeInWidth(self.textLabel.attributedStringValue, width: textMaxWidth)
            let dateSize = ChatMessageView.textSizeInWidth(self.timeLabel.attributedStringValue, width: textMaxWidth)
            
            backgroundFrame.size.width = ChatMessageView.widthOfBackground(textWidth: textSize.width)
            if mmsView.frame.width > 0 {
                backgroundFrame.size.width += mmsView.frame.width + 20
            }
            backgroundFrame.size.height =  textSize.height + ChatMessageView.VerticalTextPadding / 2 + 5
            if mmsView.frame.height > 0 {
                backgroundFrame.size.height += mmsView.frame.height + 20
            }
            
            switch (orientation) {
            case .Left:
                backgroundFrame.origin.x = frame.origin.x + paddingEdges
                
                backgroundView.layer!.backgroundColor = NSColor.NSColorFromHex(messagesGray).CGColor
                textLabel.layer!.backgroundColor = NSColor.NSColorFromHex(messagesGray).CGColor
                textLabel.textColor = NSColor.blackColor()
                break
                
            case .Right:
                backgroundFrame.origin.x = frame.size.width - backgroundFrame.size.width - paddingEdges
                
                backgroundView.layer!.backgroundColor = NSColor.NSColorFromHex(messagesBlue).CGColor
                textLabel.layer!.backgroundColor = NSColor.NSColorFromHex(messagesBlue).CGColor
                textLabel.textColor = NSColor.whiteColor()
                break
            }
            
            backgroundView.frame = backgroundFrame
            if message.sms! == false && message.messageparts!.count > 0 {
                var contenttype = 0
                for var part in 0...message.messageparts!.count-1{
                    let dict = message.messageparts![part] as! MessagePart
                    NSLog(dict.content_type!)
                    if dict.content_type! != "text/plain" {
                        contenttype += 1
                    }
                }
                backgroundFrame.size.height += msgHeight
            }
            
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
                mmsView.frame.origin.x = frame.origin.x + paddingEdges + (backgroundFrame.size.width - mmsView.frame.size.width) / 2
                mmsView.frame.origin.y = backgroundView.frame.origin.y + ChatMessageView.TextTopBorder - (ChatMessageView.VerticalTextPadding / 2) + 30
                
            case .Right:
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
                
                mmsView.frame.origin.x = frame.size.width - paddingEdges - backgroundFrame.size.width + (backgroundFrame.size.width - mmsView.frame.size.width) / 2
                mmsView.frame.origin.y = backgroundView.frame.origin.y + ChatMessageView.TextTopBorder - (ChatMessageView.VerticalTextPadding / 2) + 30
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
    
    class func heightForContainerWidth(msg: Message, width: CGFloat) -> CGFloat {
        let text = NSMutableAttributedString(string: msg.msg!)
        let size = textSizeInWidth(text, width: widthOfText(backgroundWidth: (width * WidthPercentage)))
        var height = size.height + TimeHeight + TextTopBorder + TextBottomBorder// + 30
        
        if msg.sms! == false && msg.messageparts!.count > 0 {
            var contenttype = 0
            for var part in 0...msg.messageparts!.count-1{
                let dict = msg.messageparts![part] as! MessagePart
                if dict.content_type! != "text/plain" {
                    contenttype += 1
                }
            }
            height += CGFloat(CGFloat(contenttype) * MMSHeight + 40 * CGFloat(contenttype))
        }
        
        return height
    }
    
    
}