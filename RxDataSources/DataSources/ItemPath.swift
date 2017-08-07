//
//  ItemPath.swift
//  RxContact
//
//  Created by javierfuchs on 1/21/2017.
//  Copyright © 2017 Mobile Patagonia. All rights reserved.
//

import Foundation

public struct ItemPath {
    public let sectionIndex: Int
    public let itemIndex: Int
}

extension ItemPath : Equatable {
    
}

public func == (lhs: ItemPath, rhs: ItemPath) -> Bool {
    return lhs.sectionIndex == rhs.sectionIndex && lhs.itemIndex == rhs.itemIndex
}
