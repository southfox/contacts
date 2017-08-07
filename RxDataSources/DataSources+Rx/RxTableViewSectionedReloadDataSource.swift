// esto esta inspirado, y quizas afanado.

import Foundation
import UIKit
import RxSwift
import RxCocoa


open class RxTableViewSectionedReloadDataSource<S: SectionModelType>
    : TableViewSectionedDataSource<S>
    , RxTableViewDataSourceType {
    public typealias Element = [S]

    public override init() {
        super.init()
    }

    open func tableView(_ tableView: UITableView, observedEvent: Event<Element>) {
        UIBindingObserver(UIElement: self) { dataSource, element in
            dataSource.setSections(element)
            tableView.reloadData()
        }.on(observedEvent)
    }
}
