//
//  ContactViewModel.swift
//  RxContact
//
//  Created by javierfuchs on 7/20/2017.
//  Copyright © 2017 Mobile Patagonia. All rights reserved.
//

import RxSwift
import RxCocoa


class ContactViewModel {
    var contact: Contact {
        didSet {
            
        self.title = Driver.never()
        self.secondTitle = Driver.never()
        
        self.title = configureTitle().asDriver(onErrorJustReturn: "🐞 Error during fetching 🐞")
        self.secondTitle = configureSecondTitle().asDriver(onErrorJustReturn: "🐞 Please contact us claiming this error 🐞")
            
        }
    }
    

    var title: Driver<String>
    var secondTitle: Driver<String>

    let REST = DefaultContactREST.instance
    let $: Factory = Factory.instance

    init(contact: Contact) {
        self.contact = contact

        self.title = Driver.never()
        self.secondTitle = Driver.never()
        
        self.title = configureTitle().asDriver(onErrorJustReturn: "🐞 Error during fetching 🐞")
        self.secondTitle = configureSecondTitle().asDriver(onErrorJustReturn: "🐞 Please contact us claiming this error 🐞")

    }

    // private methods

    func configureTitle() -> Observable<String> {
        let loadingValue: String? = nil
        let contact = self.contact
        return secondTitle
            .map(Optional.init)
            .startWith(loadingValue)
            .map { _ in
                if contact.last.isEmpty && contact.first.isEmpty {
                    return "🆕 Add new Contact"
                }
                return "👤\(contact.last), \(contact.first)"
            }
            .retryOnBecomesReachable("🐞 There is no Internet connection 🐞", reachabilityService: $.reachabilityService)
        
    }
    
    func configureSecondTitle() -> Observable<String> {
        let loadingValue: String? = nil
        let contact = self.contact
        return secondTitle
            .map(Optional.init)
            .startWith(loadingValue)
            .map { _ in
                if contact.last.isEmpty && contact.first.isEmpty {
                    return ""
                }
                return "📱\(contact.phone) 🎂 \(contact.dob)"
            }
            .retryOnBecomesReachable("🐞 There is no Internet connection 🐞", reachabilityService: $.reachabilityService)
    }
}
