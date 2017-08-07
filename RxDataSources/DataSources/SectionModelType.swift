//
//  SectionModelType.swift
//  RxContact
//
//  Created by javierfuchs on 1/13/2017.
//  Copyright © 2017 Mobile Patagonia. All rights reserved.
//

import Foundation

public protocol SectionModelType {
    associatedtype Item

    var items: [Item] { get }

    init(original: Self, items: [Item])
}
