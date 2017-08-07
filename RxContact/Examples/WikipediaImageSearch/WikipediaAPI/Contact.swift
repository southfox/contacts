//
//  Contact.swift
//  RxContact
//
//  Created by javierfuchs on 6/8/2017.
//  Copyright © 2017 Mobile Patagonia. All rights reserved.
//

import RxSwift

import struct Foundation.URL

struct Contact: CustomDebugStringConvertible {
    var id : String?
    let first: String
    let last: String
    let dob: String
    let phone: String
    let zip: Int
    
    static func parseJSON(_ json: [String : [String : Any?] ], query: String?) throws -> [Contact] {
        var array = [Contact]()
        for (id, dict) in json {
            let first = dict["first"] as? String ?? ""
            let last = dict["last"] as? String ?? ""
            let phone = dict["phone"] as? String ?? ""
            let dob = dict["dob"] as? String ?? ""
            let zip = dict["zip"] as? Int ?? 0
            if let query = query, !query.isEmpty {
                let lowercase = "\(first)-\(last)".lowercased()
                if !lowercase.contains(query.lowercased()) {
                    continue
                }
            }
            array.append(Contact(id: id, first: first, last: last, dob: dob, phone: phone, zip: zip))
        }
        return array
    }
    static func create() {
        
    }
}

extension Contact {
    var debugDescription: String {
        return "[\(last)](\(first))"
    }
    var description : String {
        return "\(first)-\(last)"
    }
    
    var dictString : String {
        var str = "{"
        str += "\"first\" : \"\(first)\", "
        str += "\"last\" : \"\(last)\", "
        str += "\"dob\" : \"\(dob)\", "
        str += "\"phone\" : \"\(phone)\", "
        str += "\"zip\" : \(zip)"
        str += "}"
        return str
    }
}
