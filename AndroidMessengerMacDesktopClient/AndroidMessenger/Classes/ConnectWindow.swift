//
//  ConnectWindow.swift
//  messageme
//
//  Created by Kalyan Vishnubhatla on 9/14/15.
//  Copyright (c) 2015 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa
import SwiftyJSON

protocol ConnectProtocol {
    func sheetShouldClose()
}

class ConnectWindow: NSWindowController {
    var parent: ConnectProtocol? = nil
    
    @IBOutlet weak var ipAddressField: NSTextField!
    @IBOutlet weak var progressLabel: NSTextField!
    @IBOutlet weak var connect: NSButton!
    @IBOutlet weak var cancel: NSButton!
    
    var timer: NSTimer?
    var countDown = -1
    
    class func instantiateForModalParent(parent: NSViewController) -> ConnectWindow {
        let discoverable = ConnectWindow(windowNibName: "ConnectWindow")
        return discoverable
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    func start() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(handleNotification), name: websocketHandshake, object: nil)
        if (NSUserDefaults.standardUserDefaults().valueForKey(ipAddress) != nil) {
            ipAddressField.stringValue = NSUserDefaults.standardUserDefaults().valueForKey(ipAddress) as! String
        }
    }
    
    func handleNotification(notification: NSNotification) {
        switch notification.name {
        case websocketHandshake:
            // We're done
            progressLabel.stringValue = "Connected"
            NetworkingUtil._manager = nil
            NSNotificationCenter.defaultCenter().postNotificationName(connectedNotification, object: nil)
            closeWindow()
            break
            
        default:
            break
        }
    }
    
    func connectionError() {
        NSLog("Error connecting")
    }
    
    func closeWindow() {
        if (timer != nil) {
            timer!.invalidate()
        }
        
        if (self.parent != nil) {
            NSNotificationCenter.defaultCenter().removeObserver(self, name: websocketConnected, object: nil)
            NSNotificationCenter.defaultCenter().removeObserver(self, name: websocketDisconnected, object: nil)
            self.parent?.sheetShouldClose()
        }
    }
    
    @IBAction func connectButtonClicked(sender: AnyObject) {
        progressLabel.stringValue = "Connecting ..."
        
        // Validate IP Address before attempting to connect
        if ipAddressField.stringValue.isValidIPAddress() {
            NSUserDefaults.standardUserDefaults().setValue(ipAddressField.stringValue, forKey: ipAddress)
            NSUserDefaults.standardUserDefaults().synchronize()
            
            NSNotificationCenter.defaultCenter().postNotificationName(websocketConnected, object: nil)
            let prefs = NSUserDefaults.standardUserDefaults()
            prefs.setObject(String(format: "https://%@:%@", ipAddressField.stringValue, "5000"), forKey: fullUrlPath)
            prefs.setObject(ipAddressField.stringValue, forKey: ipAddress)
            prefs.synchronize()

            closeWindow()
        } else {
            progressLabel.stringValue = "Invalid IP Address."
        }
    }
    
    @IBAction func stopButtonClicked(sender: AnyObject) {
        closeWindow()
    }
}