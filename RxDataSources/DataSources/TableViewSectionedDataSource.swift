// esto esta inspirado, y quizas afanado.

import Foundation
import UIKit
import RxCocoa

open class _TableViewSectionedDataSource
    : NSObject
    , UITableViewDataSource {
    
    open func _rx_numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    open func numberOfSections(in tableView: UITableView) -> Int {
        return _rx_numberOfSections(in: tableView)
    }

    open func _rx_tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return _rx_tableView(tableView, numberOfRowsInSection: section)
    }

    open func _rx_tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return (nil as UITableViewCell?)!
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return _rx_tableView(tableView, cellForRowAt: indexPath)
    }

    open func _rx_tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }
    
    open func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return _rx_tableView(tableView, titleForHeaderInSection: section)
    }

    open func _rx_tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return nil
    }
    
    open func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return _rx_tableView(tableView, titleForFooterInSection: section)
    }
    
    open func _rx_tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    open func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return _rx_tableView(tableView, canEditRowAt: indexPath)
    }
    
    open func _rx_tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    open func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return _rx_tableView(tableView, canMoveRowAt: indexPath)
    }

    #if os(iOS)
    open func _rx_sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return nil
    }
    
    open func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return _rx_sectionIndexTitles(for: tableView)
    }

    open func _rx_tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return 0
    }

    open func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return _rx_tableView(tableView, sectionForSectionIndexTitle: title, at: index)
    }
    #endif

    open func _rx_tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
    }

    open func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        _rx_tableView(tableView, moveRowAt: sourceIndexPath, to: destinationIndexPath)
    }

}

open class TableViewSectionedDataSource<S: SectionModelType>
    : _TableViewSectionedDataSource
    , SectionedViewDataSourceType {
    
    public typealias I = S.Item
    public typealias Section = S
    public typealias CellFactory = (TableViewSectionedDataSource<S>, UITableView, IndexPath, I) -> UITableViewCell

    // This structure exists because model can be mutable
    // In that case current state value should be preserved.
    // The state that needs to be preserved is ordering of items in section
    // and their relationship with section.
    // If particular item is mutable, that is irrelevant for this logic to function
    // properly.
    public typealias SectionModelSnapshot = SectionModel<S, I>
    
    private var _sectionModels: [SectionModelSnapshot] = []

    open var sectionModels: [S] {
        return _sectionModels.map { Section(original: $0.model, items: $0.items) }
    }

    open subscript(section: Int) -> S {
        var sectionModel = self._sectionModels[0]
        if section < self.sectionModels.count {
            sectionModel = self._sectionModels[section]
        }
        return S(original: sectionModel.model, items: sectionModel.items)
    }

    open subscript(indexPath: IndexPath) -> I {
        get {
            return self._sectionModels[indexPath.section].items[indexPath.item]
        }
        set(item) {
            if indexPath.section < self._sectionModels.count {
                var section = self._sectionModels[indexPath.section]
                if indexPath.item < section.items.count {
                    section.items[indexPath.item] = item
                }
                self._sectionModels[indexPath.section] = section
            }
        }
    }

    open func model(at indexPath: IndexPath) throws -> Any {
        return self[indexPath]
    }

    open func setSections(_ sections: [S]) {
        self._sectionModels = sections.map { SectionModelSnapshot(model: $0, items: $0.items) }
    }

    open var configureCell: CellFactory! = nil {
        didSet {
        }
    }
    
    open var titleForHeaderInSection: ((TableViewSectionedDataSource<S>, Int) -> String?)? {
        didSet {
        }
    }
    open var titleForFooterInSection: ((TableViewSectionedDataSource<S>, Int) -> String?)? {
        didSet {
        }
    }
    
    open var canEditRowAtIndexPath: ((TableViewSectionedDataSource<S>, IndexPath) -> Bool)? {
        didSet {
        }
    }
    open var rowAnimation: UITableViewRowAnimation = .automatic

    #if os(iOS)
    open var sectionIndexTitles: ((TableViewSectionedDataSource<S>) -> [String]?)? {
        didSet {
        }
    }
    open var sectionForSectionIndexTitle:((TableViewSectionedDataSource<S>, _ title: String, _ index: Int) -> Int)? {
        didSet {
        }
    }
    #endif
    
    public override init() {
        super.init()
        self.configureCell = { [weak self] _ in
            if let strongSelf = self {
                precondition(false, "There is a minor problem. `cellFactory` property on \(strongSelf) was not set. Please set it manually, or use one of the `rx_bindTo` methods.")
            }
            
            return (nil as UITableViewCell!)!
        }
    }
    
    // UITableViewDataSource
    
    open override func _rx_numberOfSections(in tableView: UITableView) -> Int {
        if tableView.isEditing {
            return _sectionModels.count
        }
        return 1
    }
    
    open override func _rx_tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section < _sectionModels.count {
            return _sectionModels[section].items.count
        }
        return 0
    }
    
    open override func _rx_tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        precondition(indexPath.item < _sectionModels[indexPath.section].items.count)
        
        return configureCell(self, tableView, indexPath, self[indexPath])
    }
    
    open override func _rx_tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section < _sectionModels.count {
            return titleForHeaderInSection?(self, section)
        }
        return nil
    }
        
    
    open override func _rx_tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return titleForFooterInSection?(self, section)
    }
    
    open override func _rx_tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let canEditRow = canEditRowAtIndexPath?(self, indexPath) else {
            return super._rx_tableView(tableView, canEditRowAt: indexPath)
        }
        
        return canEditRow
    }
   
    #if os(iOS)
    open override func _rx_sectionIndexTitles(for tableView: UITableView) -> [String]? {
        guard let titles = sectionIndexTitles?(self) else {
            return super._rx_sectionIndexTitles(for: tableView)
        }
        
        return titles
    }
    
    open override func _rx_tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        guard let section = sectionForSectionIndexTitle?(self, title, index) else {
            return super._rx_tableView(tableView, sectionForSectionIndexTitle: title, at: index)
        }
        
        return section
    }
    #endif
}
