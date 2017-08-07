//
//  ContactREST.swift
//  RxContact
//
//  Created by javierfuchs on 6/28/2017.
//  Copyright © 2017 Mobile Patagonia. All rights reserved.
//

import RxSwift
import RxCocoa


func apiError(_ code: Int? = 0, desc: String) -> NSError {
    var id = "contacts"
    if let bundleId = Bundle.main.bundleIdentifier {
        id = bundleId
    }
    return NSError(domain: id, code: code ?? 0, userInfo: [NSLocalizedDescriptionKey: desc])
}

public let ContactParseError = apiError(desc: "🐞Error during parsing🐞")

struct ContactResult: CustomDebugStringConvertible {
    var response : URLResponse? = nil
    var data : Data? = nil
    var error : Error? = nil
    
    init(response: URLResponse?, data: Data?, error: Error?) {
        self.response = response
        self.data = data
        self.error = error
    }
}

extension ContactResult {
    public var debugDescription: String {
        var str : String = "\(type(of:self)): "
        if let data = data,
           let dataStr = String.init(data: data, encoding: .utf8) {
            str += "data = \(dataStr), "
        }
        if let httpResponse = response as? HTTPURLResponse {
            str += "statusCode = \(httpResponse.statusCode), "
        }
        if let error = error {
            str += "error = \(error.localizedDescription), "
        }
        return str
    }
}


protocol ContactREST {
    func searchContacts(_ query: String?) -> Observable<[Contact]>
}


class DefaultContactREST: ContactREST {

    static let instance = DefaultContactREST()
    
    let $: Factory = Factory.instance

    let loadingContactData = ObservableSharedSequence()

    let disposeBag = DisposeBag()

    private init() {}

    private func JSON(_ url: URL) -> Observable<Any> {
        return $.URLSession
            .rx.json(url: url)
            .trackActivity(loadingContactData)
    }
    
    private func http(method: String, url: URL, body: String? = nil) -> Observable<ContactResult> {
        
        return Observable.create { observer in
            var request = URLRequest(url: url)
            request.httpMethod = method
            if let body = body {
                request.httpBody = body.data(using: .utf8)
            }
            let task = self.$.URLSession.dataTask(with: request) {
                data, response, error in
                
                guard let response = response, let data = data else {
                    observer.on(.error(error ?? RxCocoaError.unknown))
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    observer.on(.error(RxCocoaError.unknown))
                    return
                }
                print(httpResponse)
                print(data.count)
                observer.on(.next(ContactResult(response: response, data: data, error: error)))
            }
            task.resume()
            
            return Disposables.create {
//                task.cancel()
            }
        }
    }
    
    private func DELETE(_ url: URL) -> Observable<Bool> {
        return http(method: "DELETE", url: url).map({ (contactResult) -> Bool in
            if contactResult.error == nil {
                return true
            }
            else {
                return false
            }
        })
    }
    
    // return id of the new contact if created
    private func POST(_ url: URL, body: String) -> Observable<String?> {
        return http(method: "POST", url: url, body: body).map({ (contactResult) -> String? in
            if contactResult.error != nil {
                return nil
            }
            var json : [String:String]? = nil
            if let data = contactResult.data {
                json = try JSONSerialization.jsonObject(with: data, options:[]) as? [String : String]
            }

            if let json = json {
                return json["name"]
            }
            return nil
        })

    }

    private func PATCH(_ url: URL, body: String) -> Observable<Bool> {
        return http(method: "PATCH", url: url).map({ (contactResult) -> Bool in
            if contactResult.error == nil {
                return true
            }
            else {
                return false
            }
        })
    }
    
    // curl 'https://contacts-4c754.firebaseio.com/.json'
    func searchContacts(_ query: String?) -> Observable<[Contact]> {
        let urlContent = "https://contacts-4c754.firebaseio.com/.json"
        guard let url = URL(string: urlContent) else {
            return Observable.error(apiError(desc: "🐞Can't create url🐞"))
        }
        
        return JSON(url)
            .observeOn($.schedulerTask)
            .map { json in
                guard let json = json as? [String : [String : Any? ]] else {
                    throw apiError(desc: "🐞Parsing error🐞")
                }
                
                return try Contact.parseJSON(json, query: query)
            }
            .observeOn($.mainScheduler)
    }
    
    // curl -X DELETE https://contacts-4c754.firebaseio.com/-KqesW2LmWt8qo6ymbmh.json
    func deleteContact(id: String?) -> Observable<Bool> {
        guard let id = id else {
            return Observable.just(false)
        }
        let urlContent = "https://contacts-4c754.firebaseio.com/\(id).json"
        guard let url = URL(string: urlContent) else {
            return Observable.just(false)
        }
        return DELETE(url)
    }
    
    
    // curl -X POST -d '{ "first": "Lio", "last": "Messi", "dob": "1913-01-01", "phone": "11132345", "zip": 3345 }' https://contacts-4c754.firebaseio.com/.json
    
    func createContact(_ contact: Contact) -> Observable<String?> {
        let urlContent = "https://contacts-4c754.firebaseio.com/.json"
        guard let url = URL(string: urlContent) else {
            return Observable.just(nil)
        }
        return POST(url, body: contact.dictString)
    }

    // curl -X PATCH -d '{ "dob": "1982-02-02" }' https://contacts-4c754.firebaseio.com/-KqesW2LmWt8qo6ymbmh.json
    func updateContact(_ contact: Contact) -> Observable<Bool> {
        guard let id = contact.id else {
            return Observable.just(false)
        }
        let urlContent = "https://contacts-4c754.firebaseio.com/\(id).json"
        guard let url = URL(string: urlContent) else {
            return Observable.just(false)
        }
        return PATCH(url, body: contact.dictString)
    }
    
    
}
