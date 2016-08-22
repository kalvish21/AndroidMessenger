//
//  NSImage-Extension.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 8/21/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa
import Foundation
import AsyncImageDownloaderOSX

extension NSImage {
    static var applicationSupportDirectory: NSURL {
        get {
            let fileManager = NSFileManager.defaultManager()
            let urls = fileManager.URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask)
            let applicationSupportDirectoryURL = urls.last!
            var _applicationSupportDirectory: NSURL? = applicationSupportDirectoryURL.URLByAppendingPathComponent(NSBundle.mainBundle().bundleIdentifier!)
            _applicationSupportDirectory = _applicationSupportDirectory!.URLByAppendingPathComponent("mmscache")
            do {
                let properties = try _applicationSupportDirectory!.resourceValuesForKeys([NSURLIsDirectoryKey])
                if let isDirectory = properties[NSURLIsDirectoryKey] as? Bool where isDirectory == false {
                    let description = NSLocalizedString("Could not access the application data folder.", comment: "Failed to initialize applicationSupportDirectory.")
                    let reason = NSLocalizedString("Found a file in its place.", comment: "Failed to initialize applicationSupportDirectory.")
                    throw NSError(domain: "NSImage", code: 201, userInfo: [
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
            return _applicationSupportDirectory!
        }
    }
    
    static func pathForUrl(url: String) -> NSURL {
        var digest = [UInt8](count: Int(CC_MD5_DIGEST_LENGTH), repeatedValue: 0)
        if let data = url.dataUsingEncoding(NSUTF8StringEncoding) {
            CC_MD5(data.bytes, CC_LONG(data.length), &digest)
        }
        
        var digestHex = ""
        for index in 0..<Int(CC_MD5_DIGEST_LENGTH) {
            digestHex += String(format: "%02x", digest[index])
        }
        
        let fileName = digestHex + ".png"
        let filepath = self.applicationSupportDirectory.URLByAppendingPathComponent(fileName).path!
        let urlFilePath = NSURL(fileURLWithPath: filepath)
        return urlFilePath
    }
    
    static func loadImageForUrl(url: String) -> NSImage? {
        let urlFilePath = pathForUrl(url)
        if NSFileManager.defaultManager().fileExistsAtPath(urlFilePath.path!) {
            return NSImage(contentsOfFile: urlFilePath.path!)
        }
        return nil
    }
    
    func saveImageInCache(url: String) {
        let urlFilePath = NSImage.pathForUrl(url)
        let bMImg = NSBitmapImageRep(data: (self.TIFFRepresentation)!)
        let dataToSave = bMImg?.representationUsingType(NSBitmapImageFileType.NSPNGFileType, properties: [NSImageCompressionFactor : 1])
        dataToSave?.writeToFile(urlFilePath.path!, atomically: true)
    }
}

