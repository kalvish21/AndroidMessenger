//
//  ViewController.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 3/21/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa
import SwiftyJSON

class ViewController: NSViewController, NSSplitViewDelegate, NSSearchFieldDelegate, NSUserNotificationCenterDelegate, ConnectProtocol {
    private lazy var connectWindow: ConnectWindow = {
        let connectWindow: ConnectWindow = ConnectWindow.instantiateForModalParent(self)
        connectWindow.parent = self
        return connectWindow
    }()
    
    private lazy var chatHandler: ChatMessageHandler = {
        return ChatMessageHandler(chatTableView: self.chatTableView, messageTextField: self.messageTextField, tokenField: self.tokenField)
    }()
    
    private lazy var leftMessageHandler: LeftMessageHandler = {
        return LeftMessageHandler(leftTableView: self.tableView, chatHandler: self.chatHandler)
    }()
    
    private lazy var contactHandler: ContactsHandler = {
        return ContactsHandler()
    }()
    
    private lazy var deleteButton: NSButton = {
        let window = (self.view.window as! WAYWindow)
        let titleBarView = window.titleBarView
        
        let deleteButtonSize = NSMakeSize(40, 21)
        let deleteButtonFrame = NSMakeRect(110 + self.textField.frame.size.width + 10, NSMidY(titleBarView.bounds) - (deleteButtonSize.height / 2), deleteButtonSize.width, deleteButtonSize.height)
        let deleteButton = NSButton(frame: deleteButtonFrame)
        deleteButton.bezelStyle = .TexturedRoundedBezelStyle
        deleteButton.action = #selector(deleteThreadAction)
        deleteButton.image = NSImage(named: "delete@2x.png")
        (deleteButton.cell as! NSButtonCell).imageScaling = .ScaleProportionallyUpOrDown
        deleteButton.enabled = false
        
        return deleteButton
    }()
    
    private lazy var textField: NSSearchField = {
        let window = (self.view.window as! WAYWindow)
        let titleBarView = window.titleBarView
        
        let textFieldSize = NSMakeSize(200, 24)
        let textField = NSSearchField(frame: NSMakeRect(70, NSMidY(titleBarView.bounds) - (textFieldSize.height / 2), textFieldSize.width, textFieldSize.height))
        textField.placeholderString = "Type to filter by name"
        textField.delegate = self.leftMessageHandler
        textField.backgroundColor = NSColor.whiteColor()
        
        return textField
    }()
    
    private lazy var composeButton: NSButton = {
        let window = (self.view.window as! WAYWindow)
        let titleBarView = window.titleBarView
        
        let composeButtonSize = NSMakeSize(40, 25)
        let composeButtonFrame = NSMakeRect(70 + self.textField.frame.size.width + 10, NSMidY(titleBarView.bounds) - (self.textField.frame.size.height / 2), composeButtonSize.width, composeButtonSize.height)
        let composeButton = NSButton(frame: composeButtonFrame)
        composeButton.bezelStyle = .TexturedRoundedBezelStyle
        composeButton.action = #selector(newMessageAction)
        composeButton.image = NSImage(named: "compose@2x.png")
        (composeButton.cell as! NSButtonCell).imageScaling = .ScaleProportionallyUpOrDown
        
        return composeButton
    }()
    
    @IBOutlet weak var splitView: NSSplitView!
    @IBOutlet weak var tableView: NSTableView!
    
    @IBOutlet weak var rightView: NSView!
    @IBOutlet weak var chatTableView: NSTableView!
    
    @IBOutlet weak var messageTextField: NSTextField!
    @IBOutlet weak var tokenField: NSTokenField!
    
    var results: Array<AnyObject> = Array<AnyObject>()
    var sheetIsOpened: Bool = false
    var createdBar: Bool = false
    
    override var representedObject: AnyObject? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.chatHandler.tokenField.hidden = true
        self.chatHandler.chatTableView.superview!.superview!.hidden = true
        self.chatHandler.messageTextField.hidden = true

        // Do any additional setup after loading the view.
        self.title = "Android Messenger"
        
        NSUserNotificationCenter.defaultUserNotificationCenter().delegate = self
        splitView.delegate = self
        
        tokenField.delegate = self.chatHandler
        
        // Message field properties
        messageTextField.enabled = false
        messageTextField.delegate = self
        messageTextField.placeholderString = "Type message and press enter"
        messageTextField.nextKeyView = tableView
        
        // Left navigation bar
        tableView.headerView = nil
        tableView.setDataSource(self.leftMessageHandler)
        tableView.setDelegate(self.leftMessageHandler)
        tableView.registerNib(NSNib(nibNamed: "MessageCell", bundle: NSBundle.mainBundle())!, forIdentifier: "MessageCell")
        tableView.nextKeyView = messageTextField
        
        // Main chat tableview settings
        chatTableView.headerView = nil
        chatTableView.setDataSource(self.chatHandler)
        chatTableView.setDelegate(self.chatHandler)
        chatTableView.backgroundColor = NSColor.whiteColor()
        chatTableView.selectionHighlightStyle = .None
        chatTableView.intercellSpacing = NSMakeSize(0, 0)
        
        // NSNotifications set for this class
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(handleNotification), name: getNewData, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(handleNotification), name: openConnectSheet, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(handleNotification), name: messageSentConfirmation, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(handleNotification), name: newMessageReceived, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(handleNotification), name: leftDataShouldRefresh, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(handleNotification), name: chatDataShouldRefresh, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(handleNotification), name: applicationBecameVisible, object: nil)
        
        // Populate left message view box
        self.leftMessageHandler.getDataForLeftTableView(false)
        self.tableView.becomeFirstResponder()
        
        // Get latest data from app if we're connected
        getLatestDataFromApp(false)
        self.leftMessageHandler.messageHandler.setBadgeCount()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        if (createdBar == false) {
            let window = (self.view.window as! WAYWindow)
            window.titleBarHeight = 38
            window.centerTrafficLightButtons = false
            let titleBarView = window.titleBarView
            titleBarView.addSubview(self.composeButton)
            titleBarView.addSubview(self.textField)
            createdBar = true
        }
    }
    
    func handleNotification(notification: NSNotification) {
        switch notification.name {
        case chatDataShouldRefresh:
            let userInfo: Dictionary<String, AnyObject>? = notification.object as? Dictionary<String, AnyObject>
            self.chatHandler.refreshIfThreadIdMatches(userInfo!["thread_id"] as! Int)
            break
        case openConnectSheet:
            sheetShouldOpen()
            break
        case getNewData:
            getLatestDataFromApp(false)
            break
        case leftDataShouldRefresh:
            self.leftMessageHandler.getDataForLeftTableView(false)
            break
        case applicationBecameVisible:
            NSLog("Got focus and will reset badge count")
            let row = self.tableView.selectedRow
            if row > -1 {
                self.leftMessageHandler.markMessagesAsReadForCurrentThread(row, threadId: self.chatHandler.thread_id!)
            }
            self.leftMessageHandler.messageHandler.setBadgeCount()
            break
        case messageSentConfirmation:
            let userInfo: Dictionary<String, AnyObject>? = notification.object as? Dictionary<String, AnyObject>
            
            // Check for user info
            if (userInfo == nil) {
                return
            }
            
            // Check that the thread id's match
            if (chatHandler.thread_id != (userInfo!["thread_id"] as! Int) && chatHandler.thread_id != (userInfo!["original_thread_id"] as! Int)) {
                return
            }
            
            let uuid = userInfo!["uuid"] as! String
            let id = userInfo!["id"] as! Int
            let original_thread_id = userInfo!["original_thread_id"] as! Int
            let thread_id = userInfo!["thread_id"] as! Int
            
            if original_thread_id >= 0 {
                for index in 1...chatHandler.results.count {
                    let newIndex = chatHandler.results.count - index
                    let msg = chatHandler.results[newIndex] as! Message
                    
                    if (msg.uuid == uuid) {
                        msg.id = id
                        msg.uuid = nil
                        msg.pending = false
                        
                        // Update table
                        let row = NSIndexSet(index: newIndex)
                        let col = NSIndexSet(index: 0)
                        
                        // Refresh the index paths necesary for this.
                        self.chatTableView.beginUpdates()
                        self.chatTableView.reloadDataForRowIndexes(row, columnIndexes: col)
                        self.chatTableView.endUpdates()
                        
                        self.leftMessageHandler.getDataForLeftTableView(false)
                        break
                    }
                }
                
            } else if (original_thread_id < 0 && thread_id != original_thread_id) {
                for index in 0...self.leftMessageHandler.compose_results.count-1 {
                    if (self.leftMessageHandler.compose_results[index]["thread_id"] as! Int) == original_thread_id {
                        self.leftMessageHandler.compose_results.removeAtIndex(index)
                        break
                    }
                }
                
                self.leftMessageHandler.getDataForLeftTableView(false)
                for index in 0...self.leftMessageHandler.results.count-1 {
                    if (self.leftMessageHandler.results[index]["thread_id"] as! Int) == thread_id {
                        self.tableView.selectRowIndexes(NSIndexSet(index: index), byExtendingSelection: false)
                        break
                    }
                }
                self.leftMessageHandler.userSelectedANewRowRefresh()
            }
            break
        case newMessageReceived:
            let userInfo: Dictionary<String, AnyObject>? = notification.object as? Dictionary<String, AnyObject>
            
            // Check for user info
            if (userInfo == nil) {
                return
            }
            
            self.chatHandler.performActionsForNewData(self.chatTableView, id_values: userInfo!["ids"] as! Array<Int>)
            self.leftMessageHandler.getDataForLeftTableView(false)
            break
        default:
            break
        }
    }
    
    // Splitview delegate methods
    func splitView(splitView: NSSplitView, shouldAdjustSizeOfSubview view: NSView) -> Bool {
        return view == rightView
    }
    
    // ===  Action methods for menu  ===
    @IBAction func connectToDevice(sender: AnyObject) {
        sheetShouldOpen()
    }
    
    @IBAction func getLatestData(sender: AnyObject) {
        getLatestDataFromApp(sender.tag == 1)
    }
    
    @IBAction func refreshContacts(sender: AnyObject) {
        self.contactHandler.requestContactsFromPhone()
    }
    
    func getLatestDataFromApp(forceRefresh: Bool) {
        // Figure out if we're doing refresh or not of all data
        var refresh = forceRefresh
        var maxDate =  ""
        if (refresh == false) {
            let max = getMaxDateFromCoreData()
            if (max == "") {
                // We had no data anyway to get max for
                refresh = true
            } else {
                refresh = false
                maxDate = max
            }
        }

        func responseHandler (request: NSURLRequest, response: NSHTTPURLResponse?, data: AnyObject?) -> Void {
            if (data == nil) {
                let alert = NSAlert()
                alert.messageText = "There was an error connecting to the device"
                alert.addButtonWithTitle("Okay")
                alert.runModal()
                
            } else {
                let returnValue: Array<Dictionary<String, AnyObject>> = data as! Array<Dictionary<String, AnyObject>>
                let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
                let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
                context.parentContext = delegate.coreDataHandler.managedObjectContext
                context.performBlock {
                    if (refresh) {
                        // Delete all Messages
                        var matches: [Message]?
                        do {
                            let deleteAll: NSFetchRequest = NSFetchRequest(entityName: "Message")
                            try matches = context.executeFetchRequest(deleteAll) as? [Message]
                            if (matches != nil && matches?.count > 0) {
                                for match in matches! {
                                    context.deleteObject(match)
                                }
                            }
                        } catch let error as NSError {
                            NSLog("error %@", error.localizedDescription)
                        }
                        self.leftMessageHandler.compose_results = Array<Dictionary<String, AnyObject>>()
                    }
                    
                    // Add each message
                    var array: Array<Int> = Array<Int>()
                    for dictionary in returnValue {
                        let type = dictionary["type"] as! String
                        
                        // Make sure we do not have this id already in our core data
                        let id_value = Int((dictionary["id"] as! NSString).intValue)
                        if (!refresh && self.leftMessageHandler.messageHandler.checkIfMessageExists(context, idValue: id_value)) {
                            continue
                        }
                        
                        var sms = NSEntityDescription.insertNewObjectForEntityForName("Message", inManagedObjectContext: context) as! Message
                        if (type == "sms") {
                            sms = self.leftMessageHandler.messageHandler.setMessageDetailsFromDictionary(sms, dictionary: dictionary, is_pending: false)
                        } else {
                            sms = self.leftMessageHandler.messageHandler.setMessageDetailsFromDictionaryForMms(context, sms: sms, dictionary: dictionary, is_pending: false)
                        }
                        
                        if (self.chatHandler.thread_id == sms.thread_id) {
                            array.append(Int(sms.id!))
                        }
                    }
                    
                    do {
                        try context.save()
                    } catch {
                        fatalError("Failure to save context: \(error)")
                    }
                    delegate.coreDataHandler.managedObjectContext.performBlock({
                        do {
                            try delegate.coreDataHandler.managedObjectContext.save()
                        } catch {
                            fatalError("Failure to save context: \(error)")
                        }
                    })
                    
                    if (array.count > 0) {
                        dispatch_async(dispatch_get_main_queue(),{
                            self.chatHandler.addSmsFromIdArray(array)
                        })
                    }
                    
                    dispatch_async(dispatch_get_main_queue(),{
                        self.leftMessageHandler.getDataForLeftTableView(false)
                    })
                }
            }
        }
        
        if (refresh == false && maxDate != "") {
            let net = NetworkingUtil()
            net.request(.GET, url: "messages/fromcounter", parameters: ["uid": net.generateUUID(), "c": maxDate], completionHandler: responseHandler)
            
        } else {
            let net = NetworkingUtil()
            net.request(.GET, url: "messages/all", parameters: ["uid": net.generateUUID()], completionHandler: responseHandler)
        }
    }
    
    func sendMessageToUser(address: String, message: String, identifier: String) {
        if (chatHandler.phoneNumbers == nil) {
            let alert = NSAlert()
            alert.messageText = "There is no user selected"
            alert.addButtonWithTitle("Okay")
            alert.runModal()
            return
        }
        
        func responseHandler (request: NSURLRequest, response: NSHTTPURLResponse?, data: AnyObject?) -> Void {
            if (data == nil) {
                
            } else {
                let returnValue: Array<Dictionary<String, AnyObject>> = data as! Array<Dictionary<String, AnyObject>>
                NSLog("RESPONSE %@", returnValue)
                
                let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
                let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
                context.parentContext = delegate.coreDataHandler.managedObjectContext
                
                context.performBlock {
                    // Add each message
                    var id_values: Array<Int> = Array<Int>()
                    for dictionary in returnValue {
                        
                        let id_value = Int((dictionary["id"] as! NSString).intValue)
                        if (self.leftMessageHandler.messageHandler.checkIfMessageExists(context, idValue: id_value)) {
                            continue
                        }
                        id_values.append(id_value)
                        
                        var sms = NSEntityDescription.insertNewObjectForEntityForName("Message", inManagedObjectContext: context) as! Message
                        sms = self.leftMessageHandler.messageHandler.setMessageDetailsFromDictionary(sms, dictionary: dictionary, is_pending: false)
                        NSLog("ARRAY COUNT--- %@", sms.msg!)
                    }
                    
                    do {
                        try context.save()
                        delegate.coreDataHandler.managedObjectContext.performBlock({
                            do {
                                try delegate.coreDataHandler.managedObjectContext.save()
                            } catch {
                                fatalError("Failure to save context: \(error)")
                            }
                        })
                    } catch {
                        fatalError("Failure to save context: \(error)")
                    }
                    
                    if (id_values.count > 0) {
                        dispatch_async(dispatch_get_main_queue(),{
                            self.leftMessageHandler.getDataForLeftTableView(false)
                            self.chatHandler.performActionsForNewData(self.chatTableView, id_values: id_values)
                        })
                    }
                }
            }
        }
        
        let max = getMaxDateFromCoreData()
        let net = NetworkingUtil()
        let uuid = net.generateUUID()
        let data: Dictionary<String, AnyObject> = ["uid": uuid, "n": address, "c": max, "t": message, "id": identifier]
        net.request(.POST, url: "message/send", parameters: data, completionHandler: responseHandler)
        
        messageTextField.stringValue = ""
    }
    
    func userNotificationCenter(center: NSUserNotificationCenter, didActivateNotification notification: NSUserNotification) {
        if (notification.response == nil && notification.userInfo!["thread_id"] != nil) {
            // User clicked on that notification. See if we should navigate to a new message window.
            if (notification.userInfo!["thread_id"] as? Int != self.chatHandler.thread_id) {
                self.leftMessageHandler.navigateToThread(notification.userInfo!["thread_id"] as! Int)
            }
            return
        }
        
        NSLog(notification.response!.string)
        NSLog(notification.title!)
        NSLog("%@", notification.userInfo!)
        
        NSUserDefaults.standardUserDefaults().removeObjectForKey(badgeCountSoFar)
        self.leftMessageHandler.messageHandler.setBadgeCount()
        
        prepareSendMessage(notification.userInfo!["phone_number"] as! String, message: notification.response!.string, thread_id: notification.userInfo!["thread_id"] as! Int)
    }
    
    func control(control: NSControl, textView: NSTextView, doCommandBySelector commandSelector: Selector) -> Bool {
        if (commandSelector == #selector(insertNewline)) {
            if (self.messageTextField.stringValue == "" || self.messageTextField.stringValue.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()) == "") {
                return true
            }
            prepareSendMessage(self.chatHandler.phoneNumbers![0], message: self.messageTextField.stringValue, thread_id: self.chatHandler.thread_id!)
            return true
        }
        return false
    }
    
    override func controlTextDidBeginEditing(obj: NSNotification) {
        let textView = self.view.window?.firstResponder as! NSTextView
        textView.continuousSpellCheckingEnabled = true
    }
    
    override func controlTextDidChange(obj: NSNotification) {
        // Calculate last row visible
        var bounds = self.chatTableView.superview?.bounds
        bounds!.origin.y += bounds!.size.height - 1
        let lastRowVisible = chatTableView.rowAtPoint(bounds!.origin)
        
        // Increase height of the TextField if needed
        let new_frame = NSMakeRect(messageTextField.frame.origin.x, messageTextField.frame.origin.y, messageTextField.frame.size.width, CGFloat.max)
        var height = messageTextField.cell?.cellSizeForBounds(new_frame).height
        if (height! >= 50) {
            height = 50.0
        }
        self.messageTextField.frame = NSMakeRect(self.messageTextField.frame.origin.x, self.messageTextField.frame.origin.y, self.messageTextField.frame.size.width, height!)
        NSLog("%f", self.messageTextField.frame.size.height)
        NSLog(messageTextField.stringValue)
        NSLog("%f", height!)

        if (lastRowVisible == self.chatHandler.results.count - 1) {
            self.chatTableView.scrollRowToVisible(self.chatHandler.results.count - 1)
        }
    }
    
    func prepareSendMessage(address: String, message: String, thread_id: Int) {
        let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.parentContext = delegate.coreDataHandler.managedObjectContext
        
        context.performBlock {
            var id_value: Int = 0
            repeat {
                id_value = Int.random(1000000...10000000)
            } while (self.leftMessageHandler.messageHandler.checkIfMessageExists(context, idValue: id_value))
            
            let sms = NSEntityDescription.insertNewObjectForEntityForName("Message", inManagedObjectContext: context) as! Message
            sms.id = id_value
            sms.thread_id = self.chatHandler.thread_id
            sms.address = address
            sms.msg = message
            sms.number = address
            sms.uuid = NSUUID().UUIDString
            sms.time = NSDate()
            sms.read = true
            sms.received = false
            sms.pending = true
            sms.error = false
            sms.sms = true
            
            NSLog("%@", sms)
            
            do {
                try context.save()
            } catch {
                fatalError("Failure to save context: \(error)")
            }
            delegate.coreDataHandler.managedObjectContext.performBlock({
                do {
                    try delegate.coreDataHandler.managedObjectContext.save()
                } catch {
                    fatalError("Failure to save context: \(error)")
                }
            })
            
            let objectId = sms.objectID
            dispatch_async(dispatch_get_main_queue(),{
                let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
                let context = delegate.coreDataHandler.managedObjectContext
                let _sms = context.objectWithID(objectId) as! Message
                
                if (thread_id == self.chatHandler.thread_id!) {
                    NSLog("%i", self.chatHandler.results.count)
                    
                    self.chatHandler.results.append(_sms)
                    let indexSet = NSIndexSet(index: self.chatHandler.results.count - 1)
                    self.chatTableView.beginUpdates()
                    self.chatTableView.insertRowsAtIndexes(indexSet, withAnimation: .SlideUp)
                    self.chatTableView.endUpdates()
                    self.chatTableView.scrollRowToVisible(self.chatTableView.numberOfRows - 1)
                }
                self.sendMessageToUser(address, message: message, identifier: _sms.uuid!)
            })
        }
    }
    
    func heightForStringDrawing(string: String, font: NSFont, width: CGFloat) -> CGFloat {
        let textStorage = NSTextStorage(string: string)
        let textContainer = NSTextContainer(containerSize: NSMakeSize(width, CGFloat.max))
        
        let layoutManager = NSLayoutManager()
        layoutManager.typesetterBehavior = .Behavior_10_2_WithCompatibility
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        textStorage.addAttribute(NSFontAttributeName, value: font, range: NSMakeRange(0, textStorage.length))
        textContainer.lineFragmentPadding = 0.0
        
        let glyphRange = layoutManager.glyphRangeForTextContainer(textContainer)
        layoutManager.drawGlyphsForGlyphRange(glyphRange, atPoint: NSMakePoint(0, 0))
        
        return layoutManager.usedRectForTextContainer(textContainer).size.height
    }
    
    func sheetShouldOpen() {
        if (sheetIsOpened == false) {
            self.view.window!.beginSheet(self.connectWindow.window!, completionHandler: nil)
            self.connectWindow.start()
            sheetIsOpened = true
        }
    }
    
    func sheetShouldClose() {
        sheetIsOpened = false
        self.view.window!.endSheet(self.connectWindow.window!)
    }
    
    func getMaxDateFromCoreData() -> String {
        let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.parentContext = delegate.coreDataHandler.managedObjectContext
        return self.leftMessageHandler.messageHandler.getMaxDate(context)
    }
    
    @IBAction func newMessageAction(sender: AnyObject) {
        // Only allow one new message at a time
        if (leftMessageHandler.compose_results.count == 1) {
            return
        }
        
        // user clicked on a new message button
        let compose_values = ["msg": "", "row_title": "New Message", "address": "New Message", "id": Int.random(10000000...1000000000), "thread_id": Int.random(10000000...1000000000) * -1, "read": true]
        leftMessageHandler.compose_results.append(compose_values)
        tableView.reloadData()
        
        tableView.selectRowIndexes(NSIndexSet(index: leftMessageHandler.compose_results.count - 1), byExtendingSelection: false)
        self.leftMessageHandler.userSelectedANewRowRefresh()
        tokenField.becomeFirstResponder()
    }
    
    @IBAction func deleteThreadAction(sender: AnyObject) {
        // User wants to delete the thread
        let index = self.tableView.selectedRow
        if index < 0 {
            let alert = NSAlert()
            alert.messageText = "There is no message thread selected"
            alert.addButtonWithTitle("Okay")
            alert.beginSheetModalForWindow(self.view.window!, completionHandler: nil)
            return
        }
        self.leftMessageHandler.askToDeleteThread(index, window: self.view.window!)
    }
}

