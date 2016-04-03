//
//  LeftMessageHandler.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 3/29/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa

class LeftMessageHandler: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
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
        var row_data: Dictionary<String, AnyObject>?
        if row > -1 {
            row_data = results[row] as! Dictionary<String, AnyObject>
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
                if self.chatHandler.thread_id == row_dict["thread_id"] as! Int {
                    // Select previously selected row
                    self.leftTableView.selectRowIndexes(NSIndexSet(index: row_id), byExtendingSelection: false)
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
                self.leftTableView.selectRowIndexes(NSIndexSet(index: value), byExtendingSelection: false)
                break
            }
        }
    }
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return results.count
    }
    
    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 83
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // Get an existing cell with the MyView identifier if it exists
        let result: MessageCell = {
            let result: MessageCell? = tableView.makeViewWithIdentifier("MessageCell", owner: nil) as? MessageCell
            return result!
        } ()
        
        let msg = results[row] as! Dictionary<String, AnyObject>
        
        result.nameLabel.stringValue = msg["row_title"] as! String
        result.descriptionLabel.stringValue = msg["msg"] as! String
        
        if (msg["read"] as! Bool == false && self.chatHandler.thread_id != msg["thread_id"] as! Int) {
            result.descriptionLabel.font = NSFont.boldSystemFontOfSize(13)
        } else {
            result.descriptionLabel.font = NSFont.systemFontOfSize(13)
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
    
    func tableViewSelectionDidChange(notification: NSNotification) {
        userSelectedANewRowRefresh()
    }
    
    func userSelectedANewRowRefresh() {
        // User selected a new row
        self.chatHandler.messageTextField.enabled = true
        let row = self.leftTableView.selectedRow
        
        if (row == -1) {
            return
        }
        
        let msg = results[row] as! Dictionary<String, AnyObject>
        if (msg["read"] as! Bool == false && self.chatHandler.thread_id != msg["thread_id"] as! Int) {
            let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
            let context = delegate.coreDataHandler.managedObjectContext
            let threadId = msg["thread_id"] as! Int
            let request = NSFetchRequest(entityName: "Message")
            request.predicate = NSPredicate(format: "thread_id = %i and read = %@", threadId, false)
            
            var objs: [Message]?
            do {
                try objs = context.executeFetchRequest(request) as? [Message]
            } catch let error as NSError {
                NSLog("Unresolved error: %@, %@", error, error.userInfo)
            }
            
            if (objs?.count > 0) {
                self.chatHandler.performActionsForIncomingMessages(self.leftTableView, threadId: threadId)
                
                // Update table
                let rowSet = NSIndexSet(index: row)
                let col = NSIndexSet(index: 0)
                
                // Refresh the index paths necesary for this.
                self.chatHandler.chatTableView.beginUpdates()
                self.chatHandler.chatTableView.reloadDataForRowIndexes(rowSet, columnIndexes: col)
                self.chatHandler.chatTableView.endUpdates()
                
                getDataForLeftTableView(true)
            }
        }
        
        // Set the chat data thread
        self.chatHandler.getAllDataForGroupId(msg["thread_id"] as! Int)
        self.chatHandler.chatTableView.scrollRowToVisible(self.chatHandler.chatTableView.numberOfRows - 1)
    }
}
