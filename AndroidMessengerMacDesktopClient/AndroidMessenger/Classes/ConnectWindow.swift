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
    
    class func instantiateForModalParent(parent: NSViewController) -> ConnectWindow {
        let discoverable = ConnectWindow(windowNibName: "ConnectWindow")
        return discoverable
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    }
    
    func start() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(handleNotification), name: handshake, object: nil)
        if (NSUserDefaults.standardUserDefaults().valueForKey(ipAddress) != nil) {
            
            // Get the IP Addresses
            var addresses = Array<String>()
            for address in getIFAddresses() {
                addresses.append(address)
            }
            
            // Get the QR Image generator
            let generator = QRCodeGenerator()
            generator.correctionLevel = .H
            let image:QRImage = generator.createImage(String(format: "%@", String(JSON(addresses))), size: CGSizeMake(204,204))
            customView.image = image
        }
    }
    
    func handleNotification(notification: NSNotification) {
        switch notification.name {
        case handshake:
            // We're done
            progressLabel.stringValue = "Connected"
            NetworkingUtil._manager = nil
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
        if (self.parent != nil) {
            self.parent?.sheetShouldClose()
        }
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