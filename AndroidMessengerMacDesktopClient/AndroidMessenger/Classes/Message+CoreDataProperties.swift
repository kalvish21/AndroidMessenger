//
//  Message+CoreDataProperties.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 3/26/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Message {

    @NSManaged var address: String?
    @NSManaged var error: NSNumber?
    @NSManaged var id: NSNumber?
    @NSManaged var msg: String?
    @NSManaged var number: String?
    @NSManaged var pending: NSNumber?
    @NSManaged var read: NSNumber?
    @NSManaged var received: NSNumber?
    @NSManaged var thread_id: NSNumber?
    @NSManaged var time: NSDate?
    @NSManaged var uuid: String?
    @NSManaged var sms: NSNumber?
    @NSManaged var messageparts: NSOrderedSet?
    @NSManaged var contacts: NSOrderedSet?

}
