//
//  ContactEditionViewController.swift
//  RxContact
//
//  Created by javierfuchs on 4/25/2017.
//  Copyright © 2017 Mobile Patagonia. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa


let minimalFirstnameLength = 3
let minimalLastnameLength = 3
let minimalPhoneLength = 5
let minimalZipLength = 2
let minimalDobLength = (2+1+2+1+4)

class ContactEditionViewController : UIViewController, UITextFieldDelegate {
    
    var updateBlock : ((ContactViewModel) -> Void)?
    
    var isUpdate : Bool = false

    var disposeBag: DisposeBag?
    
    var viewModel: ContactViewModel? {
        didSet {
            self.disposeBag = DisposeBag()
        }
    }
    
    @IBOutlet weak var fistnameTextField: UITextField!
    @IBOutlet weak var firstnameValidOutlet: UILabel!
    
    @IBOutlet weak var lastnameTextField: UITextField!
    @IBOutlet weak var lastnameValidOutlet: UILabel!
    
    @IBOutlet weak var phoneTextField: UITextField!
    @IBOutlet weak var phoneValidOutlet: UILabel!
    
    @IBOutlet weak var zipTextField: UITextField!
    @IBOutlet weak var zipValidOutlet: UILabel!
    
    @IBOutlet weak var dobTextField: UITextField!
    @IBOutlet weak var dobValidOutlet: UILabel!
    
    @IBOutlet weak var dobContainer: UIView!
    var dobEditionViewController : DobEditionViewController? = nil
    
    @IBOutlet weak var updateButton: UIButton!
    let dateFormatter = DateFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)

        guard let disposeBag = disposeBag else {
            return
        }
        
        if let viewModel = viewModel {
            let contact = viewModel.contact
            fistnameTextField.text = contact.first
            lastnameTextField.text = contact.last
            phoneTextField.text = contact.phone
            zipTextField.text = "\(contact.zip)"
            if contact.dob.characters.count > 0 {
                dobTextField.text = contact.dob
            }
            else {
                dateFormatter.dateFormat = "YYYY-MM-dd"
                let strDate = dateFormatter.string(from: Date())
                dobTextField.text = strDate
            }
        }

        firstnameValidOutlet.text = "Firstname has to be at least \(minimalFirstnameLength) characters"
        lastnameValidOutlet.text = "Lastname has to be at least \(minimalLastnameLength) characters"
        phoneValidOutlet.text = "Phone has to be at least \(minimalPhoneLength) characters"
        zipValidOutlet.text = "Zip has to be at least \(minimalZipLength) characters"
        dobValidOutlet.text = "DOB has to be at least \(minimalDobLength) characters"
        
        let firstnameValid = fistnameTextField.rx.text.orEmpty
            .map { $0.characters.count >= minimalFirstnameLength }
            .shareReplay(1)
        
        let lastnameValid = lastnameTextField.rx.text.orEmpty
            .map { $0.characters.count >= minimalLastnameLength }
            .shareReplay(1)
        
        let phoneValid = phoneTextField.rx.text.orEmpty
            .map { $0.characters.count >= minimalPhoneLength }
            .shareReplay(1)
        
        let zipValid = zipTextField.rx.text.orEmpty
            .map { $0.characters.count >= minimalZipLength }
            .shareReplay(1)
        
        let dobValid = dobTextField.rx.text.orEmpty
            .map { $0.characters.count >= minimalDobLength }
            .shareReplay(1)
        
        fistnameTextField.rx.controlEvent(.editingDidEnd)
            .shareReplay(1)
            .asObservable()
            .subscribe { [weak self] (event) in
                self?.view.endEditing(true)
                self?.fistnameTextField.resignFirstResponder()
            }
            .disposed(by: disposeBag)
                

        let everythingValid = Observable.combineLatest(firstnameValid, lastnameValid, phoneValid, zipValid, dobValid) { $0 && $1 && $2 && $3 && $4}
            .shareReplay(1)
        
        firstnameValid
            .bind(to: firstnameValidOutlet.rx.isHidden)
            .disposed(by: disposeBag)
        
        lastnameValid
            .bind(to: lastnameValidOutlet.rx.isHidden)
            .disposed(by: disposeBag)
        
        phoneValid
            .bind(to: phoneValidOutlet.rx.isHidden)
            .disposed(by: disposeBag)
        
        zipValid
            .bind(to: zipValidOutlet.rx.isHidden)
            .disposed(by: disposeBag)
        
        dobValid
            .bind(to: dobValidOutlet.rx.isHidden)
            .disposed(by: disposeBag)
        
        everythingValid
            .bind(to: updateButton.rx.isEnabled)
            .disposed(by: disposeBag)
        
        updateButton.rx.tap
            .subscribe(onNext: { [weak self] in self?.updateContact() })
            .disposed(by: disposeBag)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideKeyboard()
    }

    @IBAction func showDobContainer() {
        hideKeyboard()
        dobContainer.isHidden = false
        if let dobEditionViewController = dobEditionViewController {
            dobEditionViewController.dob = dobTextField.text
        }
    }
    
    func updateContact() {
        guard let viewModel = viewModel,
            let disposeBag = disposeBag else { return }
        var contact = Contact(id: viewModel.contact.id, first:fistnameTextField.text!, last: lastnameTextField.text!, dob: dobTextField.text!, phone: phoneTextField.text!, zip: Int(zipTextField.text!)!)
        if contact.id != nil {
            isUpdate = true
            DefaultContactREST.instance.updateContact(contact)
                .retry(3)
                .retryOnBecomesReachable(false, reachabilityService: Factory.instance.reachabilityService)
                .subscribe({
                    [weak self] (event) in
                    let ret = event.element ?? false
                    if ret {
                        self?.viewModel?.contact = contact  
                    }
                    self?.showInfo(onlyUpdate: true, ret: ret)
                })
                .disposed(by: disposeBag)
        }
        else {
            isUpdate = false
            DefaultContactREST.instance.createContact(contact)
                .retry(3)
                .retryOnBecomesReachable("", reachabilityService: Factory.instance.reachabilityService)
                .subscribe({
                    [weak self] (event) in
                    if let id = event.element as? String {
                        contact.id = id
                        self?.viewModel?.contact = contact
                        self?.showInfo(onlyUpdate: false, ret: true)
                    }
                    else {
                        self?.showInfo(onlyUpdate: false, ret: false)
                    }
                })
                .disposed(by: disposeBag)
        }
    }
    
    func showInfo(onlyUpdate: Bool = true, ret : Bool) {
        let message = onlyUpdate ? "Update" : "Create"
        DispatchQueue.main.async(execute: {
            [weak self] in
            self?.presentAlert((ret ? "Contact was \(message)d!" : "Fail on \(message)!"))
        })
    }

    func presentAlert(_ message: String) {
            let alertView = UIAlertController(title: "RxContact", message: message, preferredStyle: .alert)
            alertView.addAction(UIAlertAction(title: "OK", style: .cancel) { _ in
                self.navigationController?.popViewController(animated: true)
            })
        rootViewController().present(alertView, animated: true, completion: {
            [weak self] in
            if let updateBlock = self?.updateBlock,
                let viewModel = self?.viewModel,
                let isUpdate = self?.isUpdate,
                isUpdate == false {
                updateBlock(viewModel)
            }
        })
    }

    func rootViewController() -> UIViewController {
        // cheating, I know
        return UIApplication.shared.keyWindow!.rootViewController!
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? DobEditionViewController {
            viewController.dob = dobTextField.text
            viewController.closeBlock = {
                [weak self] (date) in
                if let date = date {
                    self?.dobTextField.text = date
                }
                self?.hideKeyboard()
                self?.dobContainer.isHidden = true
            }
            dobEditionViewController = viewController
            hideKeyboard()
        }
    }

    func hideKeyboard() {
        view.endEditing(true)
    }

}
