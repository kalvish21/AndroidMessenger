//
//  PhoneNumber+CoreDataProperties.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 4/2/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension PhoneNumber {

    @NSManaged var number: String?
    @NSManaged var contact: Contact?

}
