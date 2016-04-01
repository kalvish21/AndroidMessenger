//
//  NSDate.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 3/23/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Foundation

extension NSDate {    
    func convertToStringDate(format: String!) -> String {
        let dateFormatter = NSDateFormatter()
        dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
        dateFormatter.dateFormat = format
        return dateFormatter.stringFromDate(self)
    }
    
    func dateToMilliseonds() -> Double {
        return self.timeIntervalSince1970 * 1000.0
    }
    
    static func dateFromMilliseconds(ms: NSNumber) -> NSDate {
        return NSDate(timeIntervalSince1970:Double(ms) / 1000.0)
    }
}
