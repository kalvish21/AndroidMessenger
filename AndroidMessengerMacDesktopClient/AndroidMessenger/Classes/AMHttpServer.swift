//
//  HttpServer.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 8/25/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa
import Swifter
import SwiftyJSON
import libPhoneNumber_iOS


class AMHttpServer : NSObject {
    private var server: HttpServer!
    private let portNumber: in_port_t = 9192
    
    private lazy var messageHandler: MessageHandler = {
        return MessageHandler()
    }()
    
    private lazy var contactsHandler: ContactsHandler = {
        return ContactsHandler()
    }()
    
    override init() {
        super.init()
        
        self.server = HttpServer()
        
        self.server["/message/send"] = { request in
            if request.method != "POST" {
                return .OK(.Text(""))
            }
            
            let json: JSON = JSON(data: NSData(bytes: &request.body, length: request.body.count))
            print(String(json))
            self.handleMessageSent(json)
            
            return .OK(.Text(""))
        }
        
        self.server["/message/received"] = { request in
            if request.method != "POST" {
                return .OK(.Text(""))
            }
            
            let json: JSON = JSON(data: NSData(bytes: &request.body, length: request.body.count))
            print(String(json))
            
            let messages = json["messages"].array
            if (messages != nil) {
                self.parseIncomingMessagesAndShowNotification(messages!)
            }
            
            return .OK(.Text(""))
        }
    }
    
    func startServer() {
        do {
            try self.server.start(self.portNumber, forceIPv4: false, priority: 0)
            NSNotificationCenter.defaultCenter().postNotificationName(websocketConnected, object: nil)
        } catch let error as NSError {
            NSLog("error %@", error.localizedDescription)
        }
    }
    
    func stopServer() {
        do {
            try self.server.stop()
        } catch let error as NSError {
            NSLog("error %@", error.localizedDescription)
        }
    }
    
    private func handleMessageSent(jsonData: JSON) {
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
                            let objectId = Int((object["id"].stringValue))!
                            let type = object["type"].stringValue
                            if (self.messageHandler.checkIfMessageExists(context, idValue: objectId, type: type) || id_values.contains(objectId)) {
                                continue
                            }
                            
                            print("GOT TO THE NEW MESSAGE!!!! ========")
                            print("Got message: %@", objectId)
                            print("Got message type: %@", type)
                            
                            var sms = NSEntityDescription.insertNewObjectForEntityForName("Message", inManagedObjectContext: context) as! Message
                            if type == "sms" {
                                sms = self.messageHandler.setMessageDetailsFromJsonObject(sms, object: object, is_pending: false)
                            } else {
                                sms = self.messageHandler.setMessageDetailsFromJsonObjectForMms(context, sms: sms, dictionary: object, is_pending: false)
                            }
                            
                            if sms.received == false {
                                id_values.append(objectId)
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
                    let objectId = Int((object["id"].stringValue))!
                    let type = object["type"].stringValue
                    if (self.messageHandler.checkIfMessageExists(context, idValue: objectId, type: type) || id_values.contains(objectId)) {
                        continue
                    }
                    
                    print("ADDING OBJECT ID ", objectId)
                    id_values.append(objectId)
                    
                    var sms = NSEntityDescription.insertNewObjectForEntityForName("Message", inManagedObjectContext: context) as! Message
                    if type == "sms" {
                        sms = self.messageHandler.setMessageDetailsFromJsonObject(sms, object: object, is_pending: false)
                    } else {
                        sms = self.messageHandler.setMessageDetailsFromJsonObjectForMms(context, sms: sms, dictionary: object, is_pending: false)
                    }
                    
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
                    
                    var badge_count = messages.count
                    let count = NSUserDefaults.standardUserDefaults().objectForKey(badgeCountSoFar) as? String
                    if count != nil {
                        badge_count += Int(count!)!
                    }
                    
                    // Set the badge notification if we are not in the fore ground
                    if delegate.isActive == false {
                        NSUserDefaults.standardUserDefaults().setObject(String(badge_count), forKey: badgeCountSoFar)
                        self.messageHandler.setBadgeCount()
                    }
                }
            })
        }
    }
}