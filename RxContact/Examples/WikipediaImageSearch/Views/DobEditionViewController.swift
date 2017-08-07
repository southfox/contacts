//
//  DobEditionViewController.swift
//  RxContact
//
//  Created by javierfuchs on 8/7/17.
//  Copyright © 2017 Mobile Patagonia. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class DobEditionViewController : UIViewController {
    
    let disposeBag = DisposeBag()
    @IBOutlet weak var dobTextField: UITextField!
    @IBOutlet weak var datePicker: UIDatePicker!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    var closeBlock : ((String?) -> Void)?
    let dateFormatter = DateFormatter()
    
    var dob : String? {
        didSet {
            if let dob = dob {
                if let dobTextField = dobTextField {
                    dobTextField.text = dob
                    if let date = dateFormatter.date(from: dob) {
                        datePicker.date = date
                    }
                }
            }
       }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dateFormatter.dateFormat = "YYYY-MM-dd"
        
        datePicker.rx.date
            .subscribe(onNext: {
                [weak self] (date) in
                let strDate = self?.dateFormatter.string(from: date)
                self?.dobTextField.text = strDate
            })
            .disposed(by: disposeBag)
        
        cancelButton.rx.tap
            .subscribe(onNext: { [weak self] in self?.closeAction() })
            .disposed(by: disposeBag)
        
        saveButton.rx.tap
            .subscribe(onNext: { [weak self] in self?.saveAction() })
            .disposed(by: disposeBag)

    }
    
    func closeAction() {
        if let closeBlock = closeBlock {
            closeBlock(nil)
        }
    }
    
    func saveAction() {
        let strDate = dateFormatter.string(from: datePicker.date)
        dobTextField.text = strDate
        if let closeBlock = closeBlock {
            closeBlock(strDate)
        }
    }
}
