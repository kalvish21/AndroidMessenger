//
//  LoadingView.swift
//  AndroidMessenger
//
//  Created by Kalyan Vishnubhatla on 4/7/16.
//  Copyright © 2016 Kalyan Vishnubhatla. All rights reserved.
//

import Cocoa

class LoadingView: NSView {
    
    static func showLoadingView(view: NSView) {
        let topView = NSView(frame: view.bounds)
        
        let progress = NSProgressIndicator(frame: NSMakeRect(100, 100, 50, 50))
        
        let width = CGFloat(200)
        let loadingView = LoadingView(frame: NSMakeRect(view.bounds.size.width / 2 - width / 2, view.bounds.size.height / 2 - width / 2, width, width))
        loadingView.addSubview(progress)
        view.addSubview(loadingView, positioned: .Above, relativeTo: nil)

        progress.startAnimation(nil)
    }

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        // Drawing code here.
        NSColor.lightGrayColor().set()
        NSRectFill(self.bounds)
    }
}
