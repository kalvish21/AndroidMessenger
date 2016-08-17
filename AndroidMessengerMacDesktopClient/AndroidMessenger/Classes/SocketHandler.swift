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
import libPhoneNumber_iOS


class SocketHandler: NSObject, WebSocketDelegate, WebSocketPongDelegate {
    var socket: WebSocket?
    var connection_checker: dispatch_source_t?
    
    private lazy var messageHandler: MessageHandler = {
        return MessageHandler()
    }()
    
    private lazy var contactsHandler: ContactsHandler = {
        return ContactsHandler()
    }()
    
    func writeString(string: String) {
        if socket != nil && self.socket!.isConnected {
            self.socket!.writeString(string)
        }
    }
    
    func connect() {
        let prefs = NSUserDefaults.standardUserDefaults()
        if (prefs.valueForKey(ipAddress) == nil) {
            return
        }

        let url = String(format: "ws://%@:%@/%@/%@", arguments: [prefs.valueForKey(ipAddress) as! String, "5555", NetworkingUtil().generateUUID(), NSHost.currentHost().name!])
        socket = WebSocket(url: NSURL(string: url)!)
        socket!.delegate = self
        
        // http://old.dylanbeattie.net/docs/openssl_iis_ssl_howto.html
        let data: NSData? = NSData(contentsOfFile: NSBundle.mainBundle().pathForResource("ca.cer", ofType: nil)!)
        if (data != nil) {
            socket!.security = SSLSecurity(certs: [SSLCert(data: data!)], usePublicKeys: true)
        }
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
        
        let queue = dispatch_queue_create("com.androidmessenger.AndroidMessenger", nil)
        connection_checker = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue)
        dispatch_source_set_timer(connection_checker!, DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC, 1 * NSEC_PER_SEC)
        dispatch_source_set_event_handler(connection_checker!) {
            if self.socket != nil {
                self.socket!.writePing(NSData())
            } else {
                self.stopTimer()
            }
        }
        dispatch_resume(connection_checker!)
        
        NSNotificationCenter.defaultCenter().postNotificationName(websocketConnected, object: nil)
        NSUserDefaults.standardUserDefaults().setValue(websocketConnected, forKey: websocketConnected)
    }
    
    func stopTimer() {
        if (connection_checker != nil) {
            dispatch_source_cancel(connection_checker!)
            connection_checker = nil
        }
    }
    
    func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
        NSLog("Disconnected")
        
        stopTimer()
        NSNotificationCenter.defaultCenter().postNotificationName(websocketDisconnected, object: nil)
    }
    
    func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        NSLog("Received Message")
        NSLog(text)
        let jsonData = JSON(data: text.dataUsingEncoding(NSUTF8StringEncoding)!)
        
        switch (jsonData["action"].stringValue) {
        case "/message/send":
            let uuid = jsonData["uuid"]
            if uuid.error != nil {
                // uuid not present, user probably sent it from another application on their device
                let messages = jsonData["messages"].array
                if (messages != nil) {
                    let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
                    let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
                    context.parentContext = delegate.coreDataHandler.managedObjectContext
                    var id_values: Array<Int> = Array<Int>()
                    
                    context.performBlock {
                        if (messages!.count > 0) {
                            for i in 0...(messages!.count-1) {
                                let object = messages![i]
                                NSLog("%@", object.stringValue)
                                
                                // If the SMS id exists, move on
                                let objectId = Int((object["id"].stringValue))
                                if (self.messageHandler.checkIfMessageExists(context, idValue: objectId)) {
                                    continue
                                }
                                
                                let type = object["type"].stringValue
                                if (type == "mms") {
                                    break
                                }
                                
                                var sms = NSEntityDescription.insertNewObjectForEntityForName("Message", inManagedObjectContext: context) as! Message
                                sms = self.messageHandler.setMessageDetailsFromJsonObject(sms, object: object, is_pending: false)
                                
                                if sms.received == false {
                                    id_values.append(objectId!)
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
                            
                            dispatch_async(dispatch_get_main_queue(),{
                                let userInfo: Dictionary<String, AnyObject> = ["ids": id_values]
                                NSNotificationCenter.defaultCenter().postNotificationName(newMessageReceived, object: userInfo)
                            })
                        }
                    }
                }
            } else {
                // uuid is present, we are getting confirmation for a message sent through our application
                let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
                let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
                context.parentContext = delegate.coreDataHandler.managedObjectContext
                
                let request = NSFetchRequest(entityName: "Message")
                request.predicate = NSPredicate(format: "uuid = %@", jsonData["uuid"].stringValue)
                
                var objs: [Message]?
                do {
                    try objs = context.executeFetchRequest(request) as? [Message]
                } catch let error as NSError {
                    NSLog("Unresolved error: %@, %@", error, error.userInfo)
                }
                
                if (objs != nil && objs!.count == 1) {
                    context.performBlock {
                        var sms = objs![0]
                        var original_thread_id = 0
                        if sms.thread_id != nil && Int(sms.thread_id!) < 0 {
                            // This was a new message the user typed in
                            original_thread_id = Int(sms.thread_id!)
                        }
                        sms = self.messageHandler.setMessageDetailsFromJsonObject(sms, object: jsonData, is_pending: false)
                        
                        if original_thread_id < 0 {
                            // We need to update all of the other original thread_ids
                            let request = NSFetchRequest(entityName: "Message")
                            request.predicate = NSPredicate(format: "thread_id = %i", original_thread_id)
                            
                            var objs: [Message]?
                            do {
                                try objs = context.executeFetchRequest(request) as? [Message]
                            } catch let error as NSError {
                                NSLog("Unresolved error: %@, %@", error, error.userInfo)
                            }
                            
                            if objs != nil && objs?.count > 0 {
                                for obj in objs! {
                                    obj.thread_id = sms.thread_id
                                }
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
                        
                        let objectID = sms.objectID
                        dispatch_async(dispatch_get_main_queue(),{
                            let current_sms = delegate.coreDataHandler.managedObjectContext.objectWithID(objectID) as! Message
                            let userInfo: Dictionary<String, AnyObject> = ["uuid": jsonData["uuid"].stringValue, "id": current_sms.id!, "thread_id": current_sms.thread_id!, "type": current_sms.sms!, "original_thread_id": original_thread_id]
                            NSNotificationCenter.defaultCenter().postNotificationName(messageSentConfirmation, object: userInfo)
                        })
                    }
                }
            }
            break
            
        case "/new_device":
            // Parse the contacts that were attained
            self.contactsHandler.requestContactsFromPhone()
            NSNotificationCenter.defaultCenter().postNotificationName(websocketHandshake, object: nil)

            break
            
        case "/message/received":
            let messages = jsonData["messages"].array
            if (messages != nil) {
                self.parseIncomingMessagesAndShowNotification(messages!)
            }
            break
            
        case "/phone_call":
            let permission = jsonData["permission"]
            if permission != nil && permission.error == nil && permission.rawString() == "not_granted" {
                let alert = NSAlert()
                alert.messageText = "We do not have permissions to make phone calls. Please open the app and click \"Grant Phone Call Permissions\""
                alert.addButtonWithTitle("Okay")
                alert.runModal()
            }
            break
            
        default:
            break
        }
    }
    
    func websocketDidReceiveData(socket: WebSocket, data: NSData) {
        NSLog("websocketDidReceiveData")
    }
    
    func websocketDidReceivePong(socket: WebSocket) {
        NSLog("websocketDidReceivePong")
    }
    
    // Parsing SMS/MMS messages from the phone
    func parseIncomingMessagesAndShowNotification(messages: [JSON]) {
        let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.parentContext = delegate.coreDataHandler.managedObjectContext
        var id_values: Array<Int> = Array<Int>()
        NSLog("TOTAL: %i", messages.count)
        
        context.performBlock {
            var user_address: String?
            var user_message: String?
            var thread_id: Int?
            
            if (messages.count > 0) {
                for i in 0...(messages.count-1) {
                    let object = messages[i]
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
                    var title = user_address!
                    let phoneNumber: PhoneNumberData? = self.contactsHandler.getPhoneNumberIfContactExists(context, number: user_address!)
                    if phoneNumber != nil {
                        title = phoneNumber!.contact.name! as String
                    }
                    
                    // Schedule a local notification
                    let notification = NSUserNotification()
                    notification.title = title
                    notification.subtitle = user_message!
                    notification.deliveryDate = NSDate()
                    notification.userInfo = ["thread_id": thread_id!, "phone_number": user_address!]
                    
                    // Set reply field
                    notification.responsePlaceholder = "Reply"
                    notification.hasReplyButton = true
                    
                    NSUserNotificationCenter.defaultUserNotificationCenter().scheduleNotification(notification)
                    self.messageHandler.setBadgeCount()
                }
            })
        }
    }
}

