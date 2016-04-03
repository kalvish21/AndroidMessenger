//
//  ContactsHandler.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 4/3/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa
import libPhoneNumber_iOS

class ContactsHandler: NSObject {
    
    func requestContactsFromPhone() {
        func responseHandler (request: NSURLRequest, response: NSHTTPURLResponse?, data: AnyObject?) -> Void {
            if (data != nil) {
                let dataValue: Dictionary<String, AnyObject>! = data as! Dictionary<String, AnyObject>
                if dataValue["contacts"] != nil {
                    let contacts = dataValue["contacts"] as! Array<Dictionary<String, AnyObject>>
                    self.parseIncomingContactsFromAndroidDevice(contacts)
                } else if dataValue["permission"] != nil {
                    let alert = NSAlert()
                    alert.messageText = "We do not have permissions to retreive Contact names. Please open the app and click \"Grant Access to Contacts\""
                    alert.addButtonWithTitle("Okay")
                    alert.runModal()
                }
            }
        }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            let net = NetworkingUtil()
            net.request(.GET, url: "contacts", parameters: ["uid": net.generateUUID()], completionHandler: responseHandler)
        })
    }
    
    func parseIncomingContactsFromAndroidDevice(contacts: Array<Dictionary<String, AnyObject>>) {
        let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
        let context = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        context.parentContext = delegate.coreDataHandler.managedObjectContext
        
        context.performBlock {
            if (contacts.count > 0) {
                
                do {
                    var matches: [PhoneNumberData]?
                    let deleteAll: NSFetchRequest = NSFetchRequest(entityName: "PhoneNumberData")
                    try matches = context.executeFetchRequest(deleteAll) as? [PhoneNumberData]
                    if (matches != nil && matches?.count > 0) {
                        for match in matches! {
                            context.deleteObject(match)
                        }
                    }
                } catch let error as NSError {
                    NSLog("error %@", error.localizedDescription)
                }
                
                do {
                    var matches: [Contact]?
                    let deleteAll: NSFetchRequest = NSFetchRequest(entityName: "Contact")
                    try matches = context.executeFetchRequest(deleteAll) as? [Contact]
                    if (matches != nil && matches?.count > 0) {
                        for match in matches! {
                            context.deleteObject(match)
                        }
                    }
                } catch let error as NSError {
                    NSLog("error %@", error.localizedDescription)
                }
                
                for i in 0...(contacts.count-1) {
                    let object = contacts[i]
                    NSLog("%@", object)
                    
                    // If the SMS id exists, move on
                    let contact = NSEntityDescription.insertNewObjectForEntityForName("Contact", inManagedObjectContext: context) as! Contact
                    contact.id = Int((object["id"] as! String))
                    contact.name = String(object["name"] as! String)
                    
                    let numbers = NSMutableOrderedSet()
                    let array = object["phones"] as! Array<String>
                    for number in array {
                        let phone = NSEntityDescription.insertNewObjectForEntityForName("PhoneNumberData", inManagedObjectContext: context) as! PhoneNumberData
                        phone.number = number
                        phone.contact = contact
                        
                        let fmt = NBPhoneNumberUtil()
                        var fmt_number = number
                        do {
                            var nb_number: NBPhoneNumber? = nil
                            try nb_number = fmt.parse(number, defaultRegion: "US")
                            try fmt_number = fmt.format(nb_number!, numberFormat: .INTERNATIONAL)
                        } catch let error as NSError {
                            NSLog("Unresolved error: %@, %@, %@", error, error.userInfo, number)
                            fmt_number = number
                        }
                        phone.formatted_number = fmt_number
                        
                        numbers.addObject(phone)
                    }
                    contact.numbers = numbers
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
                    NSNotificationCenter.defaultCenter().postNotificationName(leftDataShouldRefresh, object: nil)
                })
            }
        }
    }
}