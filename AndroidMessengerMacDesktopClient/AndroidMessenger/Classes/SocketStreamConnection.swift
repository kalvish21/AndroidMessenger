//
//  SocketStreamConnection.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 3/22/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Foundation
import Starscream
import SwiftyJSON

class SocketHandler: NSObject, WebSocketDelegate {
    var socket: WebSocket?
    
    private lazy var messageHandler: MessageHandler = {
        return MessageHandler()
    }()
    
    func connect() {
        let prefs = NSUserDefaults.standardUserDefaults()
        if (prefs.valueForKey(ipAddress) == nil) {
            return
        }
        
        let url = String(format: "ws://%@:%@/", arguments: [prefs.valueForKey(ipAddress) as! String, "5555"])
        socket = WebSocket(url: NSURL(string: url)!)
        socket!.delegate = self
        socket!.connect()
    }
    
    func isConnected() -> Bool {
        if (socket != nil) {
            return socket!.isConnected
        }
        return false
    }
    
    func disconnect() {
        if (socket != nil) {
            socket!.disconnect()
        }
    }
    
    func websocketDidConnect(socket: WebSocket) {
        NSLog("Connected")
        
        NSNotificationCenter.defaultCenter().postNotificationName(websocketConnected, object: nil)
        NSUserDefaults.standardUserDefaults().setValue(websocketConnected, forKey: websocketConnected)
    }
    
    func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
        NSLog("Disconnected")
        NSNotificationCenter.defaultCenter().postNotificationName(websocketDisconnected, object: nil)
    }
    
    func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        NSLog("Received Message")
        NSLog(text)
        let jsonData = JSON(data: text.dataUsingEncoding(NSUTF8StringEncoding)!)
        
        switch (jsonData["action"].stringValue) {
        case "/message/send":
            let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
            let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
            context.parentContext = delegate.coreDataHandler.managedObjectContext
            
            let request = NSFetchRequest(entityName: "Message")
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "uuid = %@", jsonData["uuid"].stringValue)])
            
            var objs: [Message]?
            do {
                try objs = context.executeFetchRequest(request) as? [Message]
            } catch let error as NSError {
                NSLog("Unresolved error: %@, %@", error, error.userInfo)
            }
            
            if (objs != nil && objs!.count == 1) {
                context.performBlock {
                    let sms = self.messageHandler.setMessageDetailsFromJsonObject(objs![0], object: jsonData, is_pending: false)
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
                    
                    let objectID = sms.objectID
                    dispatch_async(dispatch_get_main_queue(),{
                        let current_sms = delegate.coreDataHandler.managedObjectContext.objectWithID(objectID) as! Message
                        let userInfo: Dictionary<String, AnyObject> = ["uuid": jsonData["uuid"].stringValue, "id": current_sms.id!, "thread_id": current_sms.thread_id!, "type": current_sms.sms!]
                        NSNotificationCenter.defaultCenter().postNotificationName(messageSentConfirmation, object: userInfo)
                    })
                }
            }
            break
            
        case "/new_device":
            NSNotificationCenter.defaultCenter().postNotificationName(websocketHandshake, object: nil)
            break
            
        case "/message/received":
            let messages = jsonData["messages"].array
            if (messages != nil) {
                self.parseIncomingMessages(messages!)
            }
            break

        case "/messages/mark_read":
            let messages = jsonData["messages"].array
            if (messages != nil) {
                self.parseIncomingMessages(messages!)
            }
            
            break
            
        default:
            break
        }
    }
    
    func websocketDidReceiveData(socket: WebSocket, data: NSData) {
        NSLog("Received Data")
    }
    
    // Parsing SMS/MMS messages from the phone
    func parseIncomingMessages(messages: [JSON]) {
        let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.parentContext = delegate.coreDataHandler.managedObjectContext
        var id_values: Array<Int> = Array<Int>()
        
        context.performBlock {
            var user_address: String?
            var user_message: String?
            var thread_id: Int?
            
            if (messages.count > 0) {
                for i in 0...(messages.count-1) {
                    let object = messages[i] as! JSON
                    NSLog("%@", object.stringValue)
                    
                    // If the SMS id exists, move on
                    let objectId = Int((object["id"].stringValue))
                    if (self.messageHandler.checkIfMessageExists(context, idValue: objectId)) {
                        continue
                    }
                    id_values.append(objectId!)
                    
                    let type = object["type"].stringValue
                    if (type == "mms") {
                        break
                    }
                    
                    var sms = NSEntityDescription.insertNewObjectForEntityForName("Message", inManagedObjectContext: context) as! Message
                    sms = self.messageHandler.setMessageDetailsFromJsonObject(sms, object: object, is_pending: false)
                    
                    user_address = sms.address!
                    user_message = sms.msg!
                    thread_id = Int(sms.thread_id!)
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
            }
            
            dispatch_async(dispatch_get_main_queue(),{
                let userInfo: Dictionary<String, AnyObject> = ["ids": id_values]
                NSNotificationCenter.defaultCenter().postNotificationName(newMessageReceived, object: userInfo)
                
                if (user_address != nil && user_message != nil) {
                    // Schedule a local notification
                    let notification = NSUserNotification()
                    notification.title = user_address!
                    notification.subtitle = user_message!
                    notification.deliveryDate = NSDate()
                    notification.userInfo = ["thread_id": thread_id!, "phone_number": user_address!]
                    
                    // Set reply field
                    notification.responsePlaceholder = "Reply"
                    notification.hasReplyButton = true
                    
                    NSUserNotificationCenter.defaultUserNotificationCenter().scheduleNotification(notification)
                }
            })
        }
    }
}

