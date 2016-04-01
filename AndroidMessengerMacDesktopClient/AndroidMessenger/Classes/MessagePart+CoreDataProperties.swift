//
//  MessagePart+CoreDataProperties.swift
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

extension MessagePart {

    @NSManaged var id: NSNumber?
    @NSManaged var content_type: String?
    @NSManaged var data: String?
    @NSManaged var message_id: NSNumber

}
