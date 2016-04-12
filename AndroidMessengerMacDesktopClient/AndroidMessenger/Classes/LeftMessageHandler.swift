//
//  LeftMessageHandler.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 3/29/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa

class LeftMessageHandler: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    var compose_results: Array<AnyObject> = Array<AnyObject>()
    var results: Array<AnyObject> = Array<AnyObject>()
    var original_results: Array<AnyObject> = Array<AnyObject>()
    var filter_value: String = ""
    var chatHandler: ChatMessageHandler!
    weak var leftTableView: NSTableView!
    
    lazy var messageHandler: MessageHandler = {
        return MessageHandler()
    }()
    
    lazy var contactsHandler: ContactsHandler = {
        return ContactsHandler()
    }()
    
    init(leftTableView: NSTableView, chatHandler: ChatMessageHandler) {
        super.init()
        
        self.leftTableView = leftTableView
        self.chatHandler = chatHandler
    }
    
    func filterTableData(filter_string: String) {
        filter_value = filter_string.lowercaseString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        if filter_value.characters.count > 0 {
            results = original_results.filter( { (result: AnyObject) -> Bool in
                let msg_title = (result as! Dictionary<String, AnyObject>)["row_title"] as! String
                let number = (result as! Dictionary<String, AnyObject>)["number"] as! String
                return msg_title.lowercaseString.rangeOfString(filter_value) != nil || number.lowercaseString.rangeOfString(filter_value) != nil
            })
        } else {
            results = original_results
        }
        self.leftTableView.reloadData()
    }
    
    override func controlTextDidChange(obj: NSNotification) {
        let textField = obj.object as! NSTextField
        let text = textField.stringValue
        filterTableData(text)
    }
    
    func getDataForLeftTableView(new_selection: Bool) {
        let row = self.leftTableView.selectedRow
        NSLog("SELECTED_ROW %i", row)
        var row_data: Dictionary<String, AnyObject>?
        if row > -1 {
            row_data = results[row] as? Dictionary<String, AnyObject>
        }
        
        let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
        original_results = self.messageHandler.getLeftMessagePaneWithLatestMessages(delegate.coreDataHandler.managedObjectContext)
        results = original_results
        if filter_value.characters.count > 0 {
            filterTableData(filter_value)
        } else {
            self.leftTableView.reloadData()
        }
        
        if row_data != nil && !new_selection {
            for row_id in 0...results.count - 1 {
                let row_dict = results[row_id]
                if self.chatHandler.thread_id == row_dict["thread_id"] as? Int {
                    // Select previously selected row
                    self.leftTableView.selectRowIndexes(NSIndexSet(index: row_id + compose_results.count), byExtendingSelection: false)
                    break
                }
            }
        }
    }
    
    func navigateToThread(thread_id: Int) {
        for value in 0...results.count-1 {
            let msg = results[value] as! Dictionary<String, AnyObject>
            let thread_id_row = msg["thread_id"] as! Int
            if thread_id_row == thread_id {
                self.leftTableView.selectRowIndexes(NSIndexSet(index: value + compose_results.count), byExtendingSelection: false)
                break
            }
        }
    }
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return results.count + compose_results.count
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // Get an existing cell with the MyView identifier if it exists
        let result: MessageCell = {
            let result: MessageCell? = tableView.makeViewWithIdentifier("MessageCell", owner: nil) as? MessageCell
            result?.nextKeyView = self.chatHandler.messageTextField
            return result!
        } ()
        
        if (row <= compose_results.count-1) {
            let msg = compose_results[row] as! Dictionary<String, AnyObject>
            result.nameLabel.stringValue = msg["row_title"] as! String
            result.descriptionLabel.stringValue = msg["msg"] as! String
        } else {
            let calculatedRow = row - compose_results.count
            let msg = results[calculatedRow] as! Dictionary<String, AnyObject>
            result.nameLabel.stringValue = msg["row_title"] as! String
            result.descriptionLabel.stringValue = msg["msg"] as! String
            
            if (msg["read"] as! Bool == false && self.chatHandler.thread_id != msg["thread_id"] as? Int) {
                result.descriptionLabel.font = NSFont.boldSystemFontOfSize(13)
            } else {
                result.descriptionLabel.font = NSFont.systemFontOfSize(13)
            }
        }
        
        // Return the result
        return result
    }
    
    func tableView(tableView: NSTableView, selectionIndexesForProposedSelection proposedSelectionIndexes: NSIndexSet) -> NSIndexSet {
        // Prevent users from deseleting rows for no rows        
        if self.leftTableView.selectedRowIndexes.count > 0 {
            let currentSelection = tableView.selectedRow
            let currentViewCell = tableView.viewAtColumn(0, row: currentSelection, makeIfNecessary: false) as? MessageCell
            if (currentViewCell != nil) {
                currentViewCell!.nameLabel.textColor = NSColor.blackColor()
            }
        }
        
        if (proposedSelectionIndexes.count == 0) {
            return tableView.selectedRowIndexes
        }
        
        // Delay textField color change
        let newViewCell = tableView.viewAtColumn(0, row: proposedSelectionIndexes.firstIndex, makeIfNecessary: false) as? MessageCell
        if (newViewCell != nil) {
            newViewCell!.nameLabel.textColor = NSColor.whiteColor()
        }
        
        return proposedSelectionIndexes
    }
    
    func tableView(tableView: NSTableView, shouldEditTableColumn tableColumn: NSTableColumn?, row: Int) -> Bool {
        return true
    }
    
    func tableView(tableView: NSTableView, shouldShowCellExpansionForTableColumn tableColumn: NSTableColumn?, row: Int) -> Bool {
        return true
    }
        
    func tableViewSelectionDidChange(notification: NSNotification) {
        self.chatHandler.messageTextField.enabled = true
        if self.leftTableView.selectedRow <= compose_results.count-1 && self.leftTableView.selectedRow >= 0 {
            let row = self.leftTableView.selectedRow
            let msg = compose_results[row] as! Dictionary<String, AnyObject>
            self.chatHandler.getAllDataForGroupId(msg["thread_id"] as! Int)
            self.chatHandler.tokenField.editable = true
            
        } else {
            userSelectedANewRowRefresh()
            self.chatHandler.tokenField.editable = false
        }
        self.messageHandler.setBadgeCount()
    }
    
    func userSelectedANewRowRefresh() {
        // User selected a new row
        let row = self.leftTableView.selectedRow - compose_results.count
        if (row < 0) {
            return
        }
        
        let msg = results[row] as! Dictionary<String, AnyObject>
        if (msg["read"] as! Bool == false && self.chatHandler.thread_id != msg["thread_id"] as? Int) {
            self.markMessagesAsReadForCurrentThread(row, threadId: msg["thread_id"] as! Int)
            getDataForLeftTableView(false)
            
        } else {
            // Set the chat data thread
            self.chatHandler.getAllDataForGroupId(msg["thread_id"] as! Int)
            self.chatHandler.chatTableView.scrollRowToVisible(self.chatHandler.chatTableView.numberOfRows - 1)
        }
    }
    
    func markMessagesAsReadForCurrentThread(row: Int, threadId: Int) {
        let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
        let context = delegate.coreDataHandler.managedObjectContext
        let request = NSFetchRequest(entityName: "Message")
        request.predicate = NSPredicate(format: "thread_id = %i and read = %@", threadId, false)
        
        var objs: [Message]?
        do {
            try objs = context.executeFetchRequest(request) as? [Message]
        } catch let error as NSError {
            NSLog("Unresolved error: %@, %@", error, error.userInfo)
        }
        
        // Set the chat data thread
        self.chatHandler.getAllDataForGroupId(threadId)
        self.chatHandler.chatTableView.scrollRowToVisible(self.chatHandler.chatTableView.numberOfRows - 1)
        
        if (objs?.count > 0) {
            let selectedRow = self.leftTableView.selectedRow
            NSLog("SELECTED ROW -- %i", selectedRow)
            self.chatHandler.performActionsForIncomingMessages(self.leftTableView, threadId: threadId)
            
            // Update table
            let rowSet = NSIndexSet(index: row)
            let col = NSIndexSet(index: 0)
            
            // Refresh the index paths necesary for this.
            self.chatHandler.chatTableView.beginUpdates()
            self.chatHandler.chatTableView.reloadDataForRowIndexes(rowSet, columnIndexes: col)
            self.chatHandler.chatTableView.endUpdates()
        }
    }
    
    func askToDeleteThread(row: Int, window: NSWindow) {
        let alert = NSAlert()
        alert.messageText = "Are you sure you want to delete this thread?"
        alert.addButtonWithTitle("Okay")
        alert.addButtonWithTitle("Cancel")
        alert.beginSheetModalForWindow(window) { (response) in
            if response == NSAlertFirstButtonReturn {
                // User wants to delete
                NSLog("User wants to delete")
                NSLog("%i", row)
                if row < 0 {
                    return
                }
                
                if row <= self.compose_results.count-1 {
                    // Delete a new message the user was composing
                    self.compose_results.removeAtIndex(row)
                    self.leftTableView.beginUpdates()
                    self.leftTableView.removeRowsAtIndexes(NSIndexSet(index: row), withAnimation: .SlideLeft)
                    self.leftTableView.endUpdates()
                    
                } else {
                    // Delete the thread that we have stored locally
                    
                    let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
                    let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
                    context.parentContext = delegate.coreDataHandler.managedObjectContext
                    
                    let msg = self.results[row] as! Dictionary<String, AnyObject>
                    let threadId = msg["thread_id"] as! Int
                    let request = NSFetchRequest(entityName: "Message")
                    request.predicate = NSPredicate(format: "thread_id = %i", threadId)
                    
                    var objs: [Message]?
                    do {
                        // Delete each message
                        try objs = context.executeFetchRequest(request) as? [Message]
                        if objs?.count > 0 {
                            for obj in objs! {
                                context.deleteObject(obj)
                            }
                        }
                        
                        // Save the context
                        try context.save()
                        delegate.coreDataHandler.managedObjectContext.performBlock({
                            do {
                                try delegate.coreDataHandler.managedObjectContext.save()
                            } catch {
                                fatalError("Failure to save context: \(error)")
                            }
                        })
                    } catch let error as NSError {
                        NSLog("Unresolved error: %@, %@", error, error.userInfo)
                    }
                    
                    // Remove from the left message pane
                    self.results.removeAtIndex(row)
                    self.leftTableView.beginUpdates()
                    self.leftTableView.removeRowsAtIndexes(NSIndexSet(index: row), withAnimation: .SlideLeft)
                    self.leftTableView.endUpdates()
                }
                
                self.chatHandler.unselectAllAndClearMessageView()
            }
        }
    }
}
