//
//  MessageHandler.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 3/27/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa
import SwiftyJSON


class MessageHandler {
    
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
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate])
        
        var results: Array<AnyObject>? = nil
        do {
            try results = moc.executeFetchRequest(request)
        } catch let error as NSError {
            NSLog("Unresolved error: %@, %@", error, error.userInfo)
        }
        
        if (results != nil) {
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
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "pending = %@", false)])
        
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
}
