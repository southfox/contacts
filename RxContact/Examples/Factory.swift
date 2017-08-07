//
//  Factory.swift
//  RxContact
//
//  Created by javierfuchs on 4/26/2017.
//  Copyright © 2017 Mobile Patagonia. All rights reserved.
//

import RxSwift

import class Foundation.URLSession
import class Foundation.OperationQueue
import enum Foundation.QualityOfService

class Factory {

    static let instance = Factory()
    
    let URLSession = Foundation.URLSession.shared
    let schedulerTask: ImmediateSchedulerType
    let mainScheduler: SerialDispatchQueueScheduler
    let reachabilityService: ReachabilityService
    private init() {
        
        let operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 2
        operationQueue.qualityOfService = QualityOfService.userInitiated
        schedulerTask = OperationQueueScheduler(operationQueue: operationQueue)
        
        mainScheduler = MainScheduler.instance
        reachabilityService = try! DefaultReachabilityService() // try! is only for simplicity sake
    }
    
}
