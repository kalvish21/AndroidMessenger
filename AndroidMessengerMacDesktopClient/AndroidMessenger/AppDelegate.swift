//
//  AppDelegate.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 3/21/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa
import ReachabilitySwift

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, SimplePingDelegate {
    
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
        
        socketHandler.socket?.writeString(dataToSend)
    }

    func applicationDidFinishLaunching(aNotification: NSNotification) {
//        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(reachabilityChanged), name: ReachabilityChangedNotification, object: nil)

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
//        do {
//            try reach = Reachability(hostname: hostName)
//            try reach!.startNotifier()
//        } catch let error as NSError {
//            NSLog("Unresolved error: %@, %@", error, error.userInfo)
//        }
        
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
    
//    func reachabilityChanged(notification:NSNotification) {
//        let reach = notification.object as? Reachability
//        if reach?.currentReachabilityStatus == .NotReachable {
//            print("not reachable")
//        } else {
//            print("reachable")
//        }
//    }
}

