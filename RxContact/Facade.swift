//
//  Facade.swift
//  RxContact
//
//  Created by javierfuchs on 6/15/2017.
//  Copyright © 2017 Mobile Patagonia. All rights reserved.
//

import Foundation
import RxSwift

class Facade {
    
    public static let instance = Facade()

    init() {
        _ = MainScheduler.instance
        _ = Factory.instance.reachabilityService
    }
}
