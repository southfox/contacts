//
//  AppDelegate.swift
//  RxContact
//
//  Created by javierfuchs on 1/7/2017.
//  Copyright © 2017 Mobile Patagonia. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(aNotification: Notification) {
        // Insert code here to initialize your application
        _ = Facade.instance
    }
    
    func applicationWillTerminate(aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    
}
