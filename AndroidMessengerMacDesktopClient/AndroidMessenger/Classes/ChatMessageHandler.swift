//
//  ChatMessageHandler.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 3/23/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa
import SwiftyJSON

class ChatMessageHandler: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    
    var results: Array<AnyObject> = Array<AnyObject>()
    var phoneNumber: String?
    var thread_id: Int? = nil
    
    lazy var messageHandler: MessageHandler = {
        return MessageHandler()
    }()
    
    weak var chatTableView: NSTableView!
    weak var messageTextField: NSTextField!

    init(chatTableView: NSTableView, messageTextField: NSTextField) {
        super.init()
        
        self.chatTableView = chatTableView
        self.messageTextField = messageTextField
        
        self.chatTableView.registerNib(NSNib(nibNamed: "ChatMessageCell", bundle: NSBundle.mainBundle())!, forIdentifier: "ChatMessageCellView")
    }
    
    func getSmsFromBackgroundThread(objectID: NSManagedObjectID) -> Message {
        let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
        let context = delegate.coreDataHandler.managedObjectContext
        let sms = context.objectWithID(objectID) as! Message;
        return sms
    }
    
    func addSmsFromIdArray(array: Array<Int>) {
        let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
        let context = delegate.coreDataHandler.managedObjectContext
        
        let request = NSFetchRequest(entityName: "Message")
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "thread_id = %i AND pending = %@ AND id in %@", thread_id!, false, array)])
        
        var current_results: Array<AnyObject> = Array<AnyObject>()
        do {
            try current_results = context.executeFetchRequest(request)
        } catch let error as NSError {
            NSLog("Unresolved error: %@, %@", error, error.userInfo)
        }
        self.results.appendContentsOf(current_results)
    }
    
    func refreshDataFromCoreData() -> [AnyObject] {
        let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
        let context = delegate.coreDataHandler.managedObjectContext
        
        let request = NSFetchRequest(entityName: "Message")
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
        
        var predicate = NSPredicate(format: "thread_id = %i AND pending = %@", thread_id!, false)
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate])
        
        var results: Array<AnyObject> = Array<AnyObject>()
        do {
            try results = context.executeFetchRequest(request)
        } catch let error as NSError {
            NSLog("Unresolved error: %@, %@", error, error.userInfo)
        }
        
        // Now get pending messages
        predicate = NSPredicate(format: "thread_id = %i AND pending = %@", thread_id!, true)
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate])
        
        var result_pending: Array<AnyObject>?
        do {
            try result_pending = context.executeFetchRequest(request)
        } catch let error as NSError {
            NSLog("Unresolved error: %@, %@", error, error.userInfo)
        }
        
        if (result_pending != nil) {
            results.appendContentsOf(result_pending!)
        }
        
        return results
    }
    
    func performActionsForIncomingMessages(tableView: NSTableView, threadId: Int) {
        // Anything that has to be done when the message window is shown (i.e. mark messages as read)
        
        // See if there're unread messages we need to mark as read (on the phone)
        let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.parentContext = delegate.coreDataHandler.managedObjectContext
        
        let request = NSFetchRequest(entityName: "Message")
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
        request.predicate = NSPredicate(format: "thread_id = %i and sms = %@ and read = %@", threadId, true, false)
        
        var message_result = Array<AnyObject>()
        do {
            try message_result = context.executeFetchRequest(request)
        } catch let error as NSError {
            NSLog("Unresolved error: %@, %@", error, error.userInfo)
        }
        
        if message_result.count > 0 {
            context.performBlock {
                var resultIds = Array<String>()
                for result in message_result {
                    let r = result as! Message
                    r.read = true
                    
                    resultIds.append(String(r.id!))
                }
                
                let json = JSON(["uid": NetworkingUtil().generateUUID(), "t": self.thread_id!, "is": resultIds, "c": self.getMaxDateFromCoreData(), "action": "/messages/mark_read"])
                delegate.socketHandler.socket?.writeString(json.rawString()!)
                
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
            }
        }
    }
    
    func performActionsForNewData(tableView: NSTableView, id_values: Array<Int>) {
        let ids_for_thread = self.checkIfIdsAreForThisThread(id_values)
        if (ids_for_thread.count == 0) {
            return
        }
        
        let initial_size = self.results.count
        self.results = self.refreshDataFromCoreData()
        let new_size = self.results.count
        
        var start_index = -1
        for msg_index in 0...ids_for_thread.count - 1 {
            let msg = ids_for_thread[msg_index] as! Message
//            NSLog("%@", msg)
            
            for index_iterate in 0...new_size {
                let newIndex = new_size - index_iterate - 1
                let msg_index = results[newIndex] as! Message
                if (msg.id! == msg_index.id!) {
                    start_index = newIndex
                    break
                }
            }
        }
        
        if initial_size < start_index {
            let row = NSMutableIndexSet()
            for value in start_index...new_size{
                NSLog("value = %i", value)
                row.addIndex(value-1)
            }
            tableView.beginUpdates()
            tableView.insertRowsAtIndexes(row, withAnimation: .SlideUp)
            tableView.endUpdates()
            
        } else {
            let rows_to_reload = NSMutableIndexSet()
            for value in start_index...initial_size {
                NSLog("%i", value - 1)
                rows_to_reload.addIndex(value-1)
            }
            let col = NSMutableIndexSet()
            col.addIndex(0)
            
            let rows_to_add = NSMutableIndexSet()
            for value in initial_size+1...new_size {
                NSLog("%i", value - 1)
                rows_to_add.addIndex(value-1)
            }
            tableView.beginUpdates()
            if (rows_to_reload.count > 0) {
                tableView.reloadDataForRowIndexes(rows_to_reload, columnIndexes: col)
            }
            
            if (rows_to_add.count > 0) {
                tableView.insertRowsAtIndexes(rows_to_add, withAnimation: .SlideUp)
            }
            tableView.endUpdates()
        }
        
        // Update the messages
        tableView.scrollRowToVisible(self.results.count - 1)
        self.performActionsForIncomingMessages(tableView, threadId: self.thread_id!)
    }
    
    func checkIfIdsAreForThisThread(ids: Array<Int>) -> [Message] {
        if (self.thread_id != nil) {
            let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
            let context = delegate.coreDataHandler.managedObjectContext
            
            let request = NSFetchRequest(entityName: "Message")
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "thread_id = %i AND id IN %@", self.thread_id!, ids)])
            request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: true)]
            
            var obtained_Values: [Message]? = nil
            do {
                try obtained_Values = context.executeFetchRequest(request) as? [Message]
            } catch let error as NSError {
                NSLog("Unresolved error: %@, %@", error, error.userInfo)
            }
            
            if (obtained_Values != nil && obtained_Values!.count > 0) {
                return obtained_Values!
            }
        }
        return []
    }
    
    func getAllDataForGroupId(threadId: Int) {
        if (thread_id != threadId) {
            NSLog("THREAD: %i", threadId)
            thread_id = threadId
            results = self.refreshDataFromCoreData()
            
            // Update the messages
            self.chatTableView.reloadData()
        }
    }
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return results.count
    }
    
    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let msg = results[row] as! NSManagedObject
        let textField = NSTextField()
        textField.font = NSFont.systemFontOfSize(13)
        textField.stringValue = msg.valueForKey("msg") as! String
        let required_height = textField.cell!.cellSizeForBounds(NSMakeRect(0, 0, tableView.frame.width - 40, CGFloat(FLT_MAX))).height
        return required_height + 35
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // Get an existing cell with the MyView identifier if it exists
        let result: ChatMessageCell = {
            let result: ChatMessageCell? = tableView.makeViewWithIdentifier("ChatMessageCellView", owner: nil) as? ChatMessageCell
            result?.chatTextField.automaticDataDetectionEnabled = true
            result?.chatTextField.font = NSFont.systemFontOfSize(13)
            return result!
        } ()
        
        do {
            let msg = results[row] as! NSManagedObject
            
            let message = msg.valueForKey("msg") as! String
            let linkedmsg = NSMutableAttributedString(string: message)
            let detector = try! NSDataDetector(types: NSTextCheckingType.Link.rawValue)
            detector.enumerateMatchesInString(message, options: [], range: NSMakeRange(0, message.characters.count), usingBlock: { (match, flag, stop) in
                if (match != nil && match?.URL != nil) {
                    linkedmsg.addAttributes([NSLinkAttributeName: match!.URL!], range: match!.range)
                }
            })

            result.chatTextField.textStorage?.setAttributedString(linkedmsg)
            result.descriptionLabel.stringValue = (msg.valueForKey("time") as! NSDate).convertToStringDate("EEEE, MMM d, yyyy h:mm a")
            if (msg.valueForKey("pending") as? Bool == true) {
                result.descriptionLabel.stringValue = "pending"
            } else if (msg.valueForKey("error") as? Bool == true) {
                result.descriptionLabel.stringValue = "failed"
            }
            result.is_sending_message = (msg.valueForKey("received") as? Bool) == false
            phoneNumber = msg.valueForKey("number") as! String
            
        } catch let error as NSError {
            NSLog("Unresolved error: %@, %@", error, error.userInfo)
        }
        
        // Return the result
        return result
    }
    
    func tableViewSelectionDidChange(notification: NSNotification) {
        // User selected a new row
    }
    
    func tableViewColumnDidResize(notification: NSNotification) {
        self.chatTableView.reloadData()
    }
    
    func getMaxDateFromCoreData() -> String {
        let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.parentContext = delegate.coreDataHandler.managedObjectContext
        return self.messageHandler.getMaxDate(context)
    }
}

