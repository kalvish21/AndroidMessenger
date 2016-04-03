//
//  NetworkingUtil.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 3/22/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Foundation
import Alamofire
import IOKit
import ReachabilitySwift

class NetworkingUtil: NSObject {
    let param_methods = [Alamofire.Method.GET, Alamofire.Method.HEAD, Alamofire.Method.DELETE]
    
    // JSON requests
    func request(method: Alamofire.Method, url: String, encoding: Alamofire.ParameterEncoding? = nil, headers: [String: String]? = nil, parameters: Dictionary<String, AnyObject>? = nil, completionHandler: (NSURLRequest, NSHTTPURLResponse?, AnyObject?) -> Void) {
        
        var encodingEvaluated = Alamofire.ParameterEncoding.JSON
        if (encoding == nil && param_methods.contains(method)) {
            encodingEvaluated = Alamofire.ParameterEncoding.URL
        } else if (encoding != nil) {
            encodingEvaluated = encoding!
        }
        
        var fullUrl = url
        let range = url.rangeOfString("http", options:.CaseInsensitiveSearch)
        if range == nil {
            fullUrl = getFullUrlPath(url)
        }
        
        Alamofire.request(method, fullUrl, parameters: parameters, encoding: encodingEvaluated, headers: headers).responseJSON { (response: Response) in
            if (response.result.error != nil || response.result.value == nil) {
                NetworkingUtil.checkForSevereError(response.request!.URL!.absoluteString)
            } else {
                var should_continue = true
                if ((response.result.value as? Dictionary<String, AnyObject>) != nil) {
                    let dict = response.result.value as! Dictionary<String, AnyObject>
                    if dict["UUID"] != nil {
                        let alert = NSAlert()
                        alert.messageText = "Seems like this device is not valid. Please check to make sure it is not synced with a different desktop."
                        alert.addButtonWithTitle("Okay")
                        alert.runModal()
                        should_continue = false
                    }
                }
                
                if (should_continue) {
                    completionHandler(response.request!, response.response, response.result.value)
                }
            }
        }
    }
    
    func getFullUrlPath(url: String!) -> String {
        let prefs = NSUserDefaults.standardUserDefaults()
        let path = prefs.valueForKey(fullUrlPath) as! String
        return String(format: "%@/%@", arguments: [path, url])
    }
    
    func generateUUID() -> String {
        let prefs = NSUserDefaults.standardUserDefaults()
        if (prefs.valueForKey(deviceUUID) == nil) {
            prefs.setObject(NSUUID().UUIDString, forKey: deviceUUID)
            prefs.synchronize()
        }
        return prefs.valueForKey(deviceUUID) as! String
    }
    
    static func checkForSevereError(url: String!){
        var reach: Reachability?
        do {
            try reach = Reachability(hostname: url)
            if (reach!.currentReachabilityStatus != .NotReachable) {
                // Test with SimplePing
                let path = NSUserDefaults.standardUserDefaults().valueForKey(ipAddress) as! String
                let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
                delegate.setupSimplePingAndRunWithHost(path)
            }
        } catch let error as NSError {
            NSLog("Unresolved error: %@, %@", error, error.userInfo)
        }
    }

}

