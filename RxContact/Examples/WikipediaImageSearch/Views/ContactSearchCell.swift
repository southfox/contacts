//
//  ContactSearchCell.swift
//  RxContact
//
//  Created by javierfuchs on 6/8/2017.
//  Copyright © 2017 Mobile Patagonia. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa


public class ContactSearchCell: UITableViewCell {

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!

    var disposeBag: DisposeBag?

    var viewModel: ContactViewModel? {
        didSet {
            let disposeBag = DisposeBag()

            guard let viewModel = viewModel else {
                return
            }

            viewModel.title
                .map(Optional.init)
                .drive(self.titleLabel.rx.text)
                .disposed(by: disposeBag)

            viewModel.secondTitle
                .map(Optional.init)
                .drive(self.descriptionLabel.rx.text)
                .disposed(by: disposeBag)


            self.disposeBag = disposeBag

        }
    }

    public override func prepareForReuse() {
        super.prepareForReuse()

        self.viewModel = nil
        self.disposeBag = nil
    }

    deinit {
    }

}

fileprivate protocol ReusableView: class {
    var disposeBag: DisposeBag? { get }
    func prepareForReuse()
}

extension ContactSearchCell : ReusableView {

}

