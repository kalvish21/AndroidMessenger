//
//  CoreDataHandler.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 3/22/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Foundation
import CoreData

class CoreDataHandler: NSObject {
    let applicationDocumentsDirectoryName = NSBundle.mainBundle().bundleIdentifier!
    let errorDomain = "CoreDataHandler"
    
    private lazy var sqlLiteFileName: String = {
        let array: [String] = self.applicationDocumentsDirectoryName.componentsSeparatedByString(".")
        return String(format: "%@.sqlite", arguments: [array.last!])
    } ()
    
    var _applicationSupportDirectory: NSURL?
    var applicationSupportDirectory: NSURL {
        get {
            if (_applicationSupportDirectory == nil) {
                let fileManager = NSFileManager.defaultManager()
                let urls = fileManager.URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask)
                let applicationSupportDirectoryURL = urls.last!
                _applicationSupportDirectory = applicationSupportDirectoryURL.URLByAppendingPathComponent(self.applicationDocumentsDirectoryName)
                do {
                    let properties = try _applicationSupportDirectory!.resourceValuesForKeys([NSURLIsDirectoryKey])
                    if let isDirectory = properties[NSURLIsDirectoryKey] as? Bool where isDirectory == false {
                        let description = NSLocalizedString("Could not access the application data folder.", comment: "Failed to initialize applicationSupportDirectory.")
                        let reason = NSLocalizedString("Found a file in its place.", comment: "Failed to initialize applicationSupportDirectory.")
                        throw NSError(domain: self.errorDomain, code: 201, userInfo: [
                            NSLocalizedDescriptionKey: description,
                            NSLocalizedFailureReasonErrorKey: reason
                        ])
                    }
                } catch let error as NSError where error.code != NSFileReadNoSuchFileError {
                    fatalError("Error occured: \(error).")
                } catch {
                    let path = _applicationSupportDirectory!.path!
                    do {
                        try fileManager.createDirectoryAtPath(path, withIntermediateDirectories:true, attributes:nil)
                    } catch {
                        fatalError("Could not create application documents directory at \(path).")
                    }
                }
            }
            return _applicationSupportDirectory!
        }
    }
    
    var _persistentStorePath: NSURL?
    var persistentStorePath: NSURL {
        get {
            if (_persistentStorePath == nil) {
                _persistentStorePath = self.applicationSupportDirectory.URLByAppendingPathComponent(self.sqlLiteFileName)
            }
            return _persistentStorePath!
        }
    }
    
    var _persistentStoreCoordinator: NSPersistentStoreCoordinator?
    var persistentStoreCoordinator: NSPersistentStoreCoordinator {
        get {
            if (_persistentStoreCoordinator == nil) {
                let options: Dictionary<NSObject, AnyObject> = [
                    NSMigratePersistentStoresAutomaticallyOption: NSNumber(bool: true),
                    NSInferMappingModelAutomaticallyOption: NSNumber(bool: true)
                ]
                
                _persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel.mergedModelFromBundles(nil)!)
                
                do {
                    try _persistentStoreCoordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: self.persistentStorePath, options: options)
                } catch let error as NSError {
                    print("Error: \(error.localizedDescription)")
                    abort()
                }
            }
            return _persistentStoreCoordinator!
        }
    }
    
    var _managedObjectContext: NSManagedObjectContext?
    var managedObjectContext: NSManagedObjectContext {
        get {
            if (_managedObjectContext == nil) {
                _managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
                _managedObjectContext!.persistentStoreCoordinator = self.persistentStoreCoordinator
            }
            return _managedObjectContext!
        }
    }
    
    func deleteAllCoreData() {
        let entities = _persistentStoreCoordinator?.managedObjectModel.entities
        for entityDescription in entities! {
            self.deleteAllObjectsForEntityDescription(entityDescription)
        }
        
        self.saveContext()
        _managedObjectContext?.reset()
        
        // Reset all core data variables
        self._persistentStorePath = nil;
        self._persistentStoreCoordinator = nil;
        self._managedObjectContext = nil;
    }
    
    func deleteAllObjectsForEntityDescription(entityDescription: NSEntityDescription) {
        let request = NSFetchRequest()
        request.entity = entityDescription
        
        do {
            try self.managedObjectContext.executeFetchRequest(request)
        } catch let error as NSError {
            NSLog("Unresolved error: %@, %@", error, error.userInfo)
        }
    }
    
    func saveContext() {
        if (self.managedObjectContext.hasChanges) {
            do {
                try self.managedObjectContext.save()
                NSLog("managedObjectContext was saved")
            } catch let error as NSError {
                NSLog("Failed to save the context: %@", error.description)
            }
        } else {
            NSLog("SKIPPED saving context because there were no changes.")
        }
    }
}