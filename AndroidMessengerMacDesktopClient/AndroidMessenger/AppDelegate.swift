//
//  AppDelegate.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 3/21/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa
import ReachabilitySwift

extension NSURLRequest {
    static func allowsAnyHTTPSCertificateForHost(host: String) -> Bool {
        return true
    }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSURLConnectionDelegate, SimplePingDelegate {
    
    let socketHandler: SocketHandler = {
        return SocketHandler()
    } ()
    
    let coreDataHandler: CoreDataHandler = {
        return CoreDataHandler()
    } ()
    
    var reach: Reachability?
    var simplePing: SimplePing?
    
    func sendMessageThroughWebsocket(dataToSend: String) {
        if (socketHandler.isConnected() == false) {
            socketHandler.connect()
        }
        
        socketHandler.writeString(dataToSend)
    }

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        if (NSUserDefaults.standardUserDefaults().valueForKey(websocketConnected) != nil && self.socketHandler.isConnected() == false) {
            self.socketHandler.connect()
        }
    }
    
    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
        if (self.socketHandler.isConnected()) {
            self.socketHandler.disconnect()
        }
        self.coreDataHandler.saveContext()
    }
    
    // Reachability delegate/helper methods
    func setupSimplePingAndRunWithHost(hostName: String) {
        simplePing = SimplePing(hostName: hostName)
        simplePing!.sendPingWithData(nil)
        simplePing!.start()
    }
    
    func simplePing(pinger: SimplePing!, didFailToSendPacket packet: NSData!, error: NSError!) {
        NSLog("didFailToSendPacket")
    }
    
    func simplePing(pinger: SimplePing!, didFailWithError error: NSError!) {
        NSLog("didFailWithError")
    }
}

