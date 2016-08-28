//
//  ConnectWindow.swift
//  messageme
//
//  Created by Kalyan Vishnubhatla on 9/14/15.
//  Copyright (c) 2015 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa
import SwiftyJSON
import QRCoder

protocol ConnectProtocol {
    func sheetShouldClose()
}

class ConnectWindow: NSWindowController {
    var parent: ConnectProtocol? = nil
    
    @IBOutlet weak var customView: NSImageView!
    @IBOutlet weak var progressLabel: NSTextField!
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
            
            NSLog("%@", getIFAddresses())
            let generator = QRCodeGenerator()
            generator.correctionLevel = .H
            let image:QRImage = generator.createImage(String(format: "%@", getIFAddresses()), size: CGSizeMake(204,204))
            customView.image = image
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
        progressLabel.stringValue = "Waiting ..."
        
        // Validate IP Address before attempting to connect
//        if ipAddressField.stringValue.isValidIPAddress() {
//            NSUserDefaults.standardUserDefaults().setValue(ipAddressField.stringValue, forKey: ipAddress)
//            NSUserDefaults.standardUserDefaults().synchronize()
//            
//            NSNotificationCenter.defaultCenter().postNotificationName(websocketConnected, object: nil)
//            let prefs = NSUserDefaults.standardUserDefaults()
//            prefs.setObject(String(format: "https://%@:%@", ipAddressField.stringValue, "5000"), forKey: fullUrlPath)
//            prefs.setObject(ipAddressField.stringValue, forKey: ipAddress)
//            prefs.synchronize()
//
//            closeWindow()
//        } else {
//            progressLabel.stringValue = "Invalid IP Address."
//        }
    }
    
    @IBAction func stopButtonClicked(sender: AnyObject) {
        closeWindow()
    }
    
    func getIFAddresses() -> [String] {
        var addresses = [String]()
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs> = nil
        if getifaddrs(&ifaddr) == 0 {
            
            // For each interface ...
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr.memory.ifa_next }
                
                let flags = Int32(ptr.memory.ifa_flags)
                var addr = ptr.memory.ifa_addr.memory
                
                // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
                if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                    if addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) {
                        
                        // Convert interface address to a human readable string:
                        var hostname = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
                        if (getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                            if let address = String.fromCString(hostname) {
                                addresses.append(address)
                            }
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return addresses
    }
}