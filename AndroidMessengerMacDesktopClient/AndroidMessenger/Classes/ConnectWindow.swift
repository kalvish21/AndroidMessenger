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
        let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
        let connectedAlready = NSUserDefaults.standardUserDefaults().stringForKey(websocketConnected)
        
        if (delegate.socketHandler.isConnected() == true) {
            progressLabel.stringValue = "Connected"
            
            let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
            delegate.socketHandler.socket?.writePing(NSData())
            
        } else if (connectedAlready != nil) {
            // We were already connected, start a count down and try again
            startTimer()
        } else {
            progressLabel.stringValue = "Type the IP Address above"
        }
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(handleNotification), name: websocketConnected, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(handleNotification), name: websocketHandshake, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(handleNotification), name: websocketDisconnected, object: nil)
        
        if (NSUserDefaults.standardUserDefaults().valueForKey(ipAddress) != nil) {
            ipAddressField.stringValue = NSUserDefaults.standardUserDefaults().valueForKey(ipAddress) as! String
        }
    }
    
    func timerCountdown(timer: NSTimer) {
        countDown = countDown - 1
        if (countDown <= 0) {
            timer.invalidate()
            connectButtonClicked(connect)
        } else {
            progressLabel.stringValue = String(format: "Trying again in %i seconds", countDown)
        }
    }
    
    func handleNotification(notification: NSNotification) {
        switch notification.name {
        case websocketConnected:
//            let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
//            let dict = ["uid": NetworkingUtil().generateUUID(), "action": "/new_device", "device": NSHost.currentHost().name!]
//            delegate.socketHandler.writeString(JSON(dict).rawString()!)
            
            let prefs = NSUserDefaults.standardUserDefaults()
            prefs.setObject(String(format: "https://%@:%@", ipAddressField.stringValue, "5000"), forKey: fullUrlPath)
            prefs.setObject(ipAddressField.stringValue, forKey: ipAddress)
            prefs.synchronize()
            break
            
        case websocketHandshake:
            // We're done
            progressLabel.stringValue = "Connected"
            NetworkingUtil._manager = nil
            NSNotificationCenter.defaultCenter().postNotificationName(connectedNotification, object: nil)
            closeWindow()
            break
            
        case websocketDisconnected:
            if (countDown == 0) {
                // We did a count down from 3 and it didn't work. User intervention required.
                progressLabel.stringValue = "Error. Could not connect to phone."
            } else {
                // Start a timr for the countdown from 3.
                startTimer()
            }
            break
            
        default:
            break
        }
    }
    
    func startTimer() {
        countDown = 3
        progressLabel.stringValue = String(format: "Trying again in %i seconds", countDown)
        timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(timerCountdown), userInfo: nil, repeats: true)
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
            
            let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
            if (delegate.socketHandler.isConnected() == false) {
                delegate.socketHandler.connect()
            } else {
                NSNotificationCenter.defaultCenter().postNotificationName(websocketConnected, object: nil)
            }
        } else {
            progressLabel.stringValue = "Invalid."
        }
    }
    
    @IBAction func stopButtonClicked(sender: AnyObject) {
        closeWindow()
    }
}