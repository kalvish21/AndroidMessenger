//
//  MessageHandler.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 3/27/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa
import SwiftyJSON
import libPhoneNumber_iOS

class MessageHandler {
    
    lazy var contactsHandler: ContactsHandler = {
        return ContactsHandler()
    }()
    
    func setMessageDetailsFromDictionary(sms: Message, dictionary: Dictionary<String, AnyObject>, is_pending: Bool) -> Message {
        NSLog("%@", dictionary)
        sms.id = Int((dictionary["id"] as! NSString).intValue)
        sms.thread_id = Int((dictionary["thread_id"] as! NSString).intValue)
        sms.address = String(dictionary["address"] as! NSString)
        sms.msg = String(dictionary["msg"] as! NSString)
        sms.number = String(dictionary["number"] as! NSString)
        sms.read = Bool(dictionary["read"] as! Bool)
        sms.received = Bool(dictionary["received"] as! Bool)
        sms.time = NSDate.dateFromMilliseconds(Double(dictionary["time"] as! String)!)
        sms.sms = String(dictionary["type"] as! NSString) == "sms"
        sms.pending = is_pending
        sms.error = dictionary["failed"] as! Bool
        return sms
    }
    
    func setMessageDetailsFromDictionaryForMms(moc: NSManagedObjectContext, sms: Message, dictionary: Dictionary<String, AnyObject>, is_pending: Bool) -> Message {
        NSLog("%@", dictionary)
        sms.id = Int((dictionary["id"] as! NSString).intValue)
        sms.thread_id = Int((dictionary["thread_id"] as! NSString).intValue)
        sms.address = String(dictionary["address"] as! NSString)
        sms.number = String(dictionary["address"] as! NSString)
        sms.read = Bool(dictionary["read"] as! Bool)
        sms.msg = ""
        sms.received = Bool(dictionary["received"] as! Bool)
        sms.time = NSDate.dateFromSeconds(Double(dictionary["time"] as! String)!)
        sms.sms = String(dictionary["type"] as! NSString) == "sms"
        sms.pending = is_pending
        
        let parts: Array<Dictionary<String, AnyObject>> = dictionary["parts"] as! Array<Dictionary<String, AnyObject>>
        if sms.messageparts == nil {
            sms.messageparts = NSMutableOrderedSet()
        }
        for var part in 0...parts.count-1{
            let dict = parts[part]
            
            switch(dict["type"] as! String) {
            case "text/plain":
                var mmspart = NSEntityDescription.insertNewObjectForEntityForName("MessagePart", inManagedObjectContext: moc) as! MessagePart
                mmspart.content_type = dict["type"] as! String
                mmspart.id = Int(dict["part_id"] as! String)!
                mmspart.message_id = Int(dict["mid"] as! String)!
                sms.msg = dict["msg"] as! String
                
                (sms.messageparts as! NSMutableOrderedSet).addObject(mmspart)
                break
                
            case "image/jpeg", "image/jpg", "image/png", "image/gif", "image/bmp":
                var mmspart = NSEntityDescription.insertNewObjectForEntityForName("MessagePart", inManagedObjectContext: moc) as! MessagePart
                mmspart.content_type = dict["type"] as! String
                mmspart.id = Int(dict["part_id"] as! String)!
                mmspart.message_id = Int(dict["mid"] as! String)!
                
                (sms.messageparts as! NSMutableOrderedSet).addObject(mmspart)
                break
                
            default:
                break
            }
        }
        
        return sms
    }

    func setMessageDetailsFromJsonObject(sms: Message, object: JSON, is_pending: Bool) -> Message {
        sms.id = Int((object["id"].stringValue))
        sms.thread_id = Int((object["thread_id"].stringValue))
        sms.address = String(object["address"].stringValue)
        sms.msg = String(object["msg"].stringValue)
        sms.number = String(object["number"].stringValue)
        sms.read = Bool(object["read"].boolValue)
        sms.received = Bool(object["received"].boolValue)
        sms.time = NSDate.dateFromMilliseconds(Double(object["time"].stringValue)!)
        sms.sms = object["type"].stringValue == "sms"
        sms.pending = is_pending
        sms.error = object["failed"].boolValue
        return sms
    }
    
    func getLeftMessagePaneWithLatestMessages(moc: NSManagedObjectContext!) -> Array<AnyObject> {
        var request = NSFetchRequest(entityName: "Message")
        request.resultType = .DictionaryResultType
        
        // max for id
        let maxExpression = NSExpression(forFunction: "max:", arguments: [NSExpression(forKeyPath: "id")])
        
        let expressionDescription = NSExpressionDescription()
        expressionDescription.name = "id"
        expressionDescription.expression = maxExpression
        expressionDescription.expressionResultType = .Integer64AttributeType
        
        request.propertiesToGroupBy = ["thread_id"]
        request.propertiesToFetch = [expressionDescription, "thread_id"]
        
        var objs = []
        do {
            try objs = moc.executeFetchRequest(request)
        } catch let error as NSError {
            NSLog("Unresolved error: %@, %@", error, error.userInfo)
        }
        
        let values = objs as! [Dictionary<String, AnyObject>]
        
        request = NSFetchRequest(entityName: "Message")
        request.sortDescriptors = [NSSortDescriptor(key: "time", ascending: false)]
        request.resultType = NSFetchRequestResultType.DictionaryResultType
        request.propertiesToFetch = ["msg", "number", "address", "id", "thread_id", "read"]
        request.returnsDistinctResults = true
        
        // Filter down based on ID's
        var idArray = Array<Int>()
        for dict in values {
            let id = dict["id"] as! Int
            idArray.append(id)
        }
        let predicate = NSPredicate(format: "id in %@", idArray)
        request.predicate = predicate
        
        var results: Array<AnyObject>? = nil
        do {
            try results = moc.executeFetchRequest(request)
        } catch let error as NSError {
            NSLog("Unresolved error: %@, %@", error, error.userInfo)
        }
        
        if (results != nil) {
            let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
            let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
            context.parentContext = delegate.coreDataHandler.managedObjectContext
            
            for i in 0...results!.count-1 {
                var result = results![i] as! Dictionary<String, AnyObject>
                let number = result["number"] as! String
                var phoneNumber: PhoneNumberData? = self.contactsHandler.getPhoneNumberIfContactExists(context, number: number)
                
                // If we got a number, then send it
                var fmt_number: String? = nil
                if phoneNumber != nil {
                    fmt_number = phoneNumber!.contact.name!
                }
                
                if fmt_number == nil {
                    fmt_number = number
                    if phoneNumber != nil && phoneNumber?.formatted_number != nil {
                        fmt_number = phoneNumber?.formatted_number
                    } else {
                        let fmt = NBPhoneNumberUtil()
                        do {
                            var nb_number: NBPhoneNumber? = nil
                            try nb_number = fmt.parse(number, defaultRegion: "US")
                            try fmt_number = fmt.format(nb_number!, numberFormat: .INTERNATIONAL)
                        } catch let error as NSError {
                            NSLog("Unresolved error: %@, %@, %@", error, error.userInfo, number)
                            fmt_number = number
                        }
                        
                        phoneNumber = self.contactsHandler.getPhoneNumberIfContactExists(context, number: fmt_number)
                        if phoneNumber != nil {
                            fmt_number = phoneNumber!.contact.name!
                        }
                    }
                }
                result.updateValue(fmt_number!, forKey: "row_title")
                results![i] = result

            }
            return results!
        }
        return []
    }
    
    func checkIfMessageExists(moc: NSManagedObjectContext!, idValue: Int!) -> Bool {
        let request = NSFetchRequest(entityName: "Message")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id = %i", idValue)
        
        var objs: [Message]?
        do {
            try objs = moc.executeFetchRequest(request) as? [Message]
        } catch let error as NSError {
            NSLog("Unresolved error: %@, %@", error, error.userInfo)
        }
        
        return objs != nil && objs!.count > 0
    }
    
    func getMaxDate(moc: NSManagedObjectContext) -> String {
        let request = NSFetchRequest(entityName: "Message")
        request.resultType = .DictionaryResultType
        
        // max for id
        let maxExpression = NSExpression(forFunction: "max:", arguments: [NSExpression(forKeyPath: "time")])
        
        let expressionDescription = NSExpressionDescription()
        expressionDescription.name = "time"
        expressionDescription.expression = maxExpression
        expressionDescription.expressionResultType = .DateAttributeType
        request.propertiesToFetch = [expressionDescription]
        request.predicate = NSPredicate(format: "pending = %@", false)
        
        var objs = [Dictionary<String, AnyObject>]()
        do {
            try objs = moc.executeFetchRequest(request) as! [Dictionary<String, AnyObject>]
            if (objs.count > 0 && objs[0]["time"] != nil) {
                var maxDateString = String((objs[0]["time"] as! NSDate).dateToMilliseonds())
                if (maxDateString.rangeOfString(".") != nil) {
                    maxDateString = maxDateString.substringToIndex(maxDateString.rangeOfString(".")!.startIndex)
                }
                return maxDateString
            }
            
        } catch let error as NSError {
            NSLog("Unresolved error: %@, %@", error, error.userInfo)
        }
        return ""
    }
    
    func setBadgeCount() {
        let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
        if delegate.isActive {
            // No need to set badge when we are active
            return
        }
        
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.parentContext = delegate.coreDataHandler.managedObjectContext
        
        let request = NSFetchRequest(entityName: "Message")
        request.predicate = NSPredicate(format: "read = %@", false)
        
        var objs = []
        do {
            try objs = context.executeFetchRequest(request)
            
            var count: String? = nil
            if objs.count > 0 {
                count = String(objs.count)
            }
            NSApplication.sharedApplication().dockTile.badgeLabel = count
        } catch let error as NSError {
            NSLog("Unresolved error: %@, %@", error, error.userInfo)
        }
    }
}
