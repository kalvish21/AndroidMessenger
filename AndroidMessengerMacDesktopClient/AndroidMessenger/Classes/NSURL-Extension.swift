//
//  NSURL-Extension.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 8/27/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa

extension NSURL {
    func getQueryItemValueForKey(key: String) -> String? {
        guard let components = NSURLComponents(URL: self, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        guard let queryItems = components.queryItems else { return nil }
        return queryItems.filter {
            $0.name == key
            }.first?.value
    }
}
