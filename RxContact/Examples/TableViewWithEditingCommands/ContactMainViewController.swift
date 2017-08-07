//
//  ContactMainViewController.swift
//  RxContact
//
//  Created by javierfuchs on 4/6/2017.
//  Copyright © 2017 Mobile Patagonia. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa


struct ContactCommandsViewModel {
    let contacts: [ContactViewModel]
    let placeholders: [ContactViewModel]

    static func executeCommand(state: ContactCommandsViewModel, _ command: ContactCommand) -> ContactCommandsViewModel {
        switch command {
        case let .setContacts(contacts):
            return ContactCommandsViewModel(contacts: contacts, placeholders: state.placeholders)
        case let .setPlaceholders(placeholders):
            return ContactCommandsViewModel(contacts: state.contacts, placeholders: placeholders)
        case let .moveContact(from, to):
            var all = [state.contacts, state.placeholders]
            let contact = all[from.section][from.row]
            all[from.section].remove(at: from.row)
            all[to.section].insert(contact, at: to.row)
            
            return ContactCommandsViewModel(contacts: all[0], placeholders: all[1])

        case let .deleteContact(indexPath):
            let disposeBag = DisposeBag()
            var all = state.contacts
            let contact = all[indexPath.row]
            DefaultContactREST.instance.deleteContact(id: contact.contact.id)
                .retry(3)
                .retryOnBecomesReachable(false, reachabilityService: Factory.instance.reachabilityService)
                .subscribe({ (event) in
                    if event.element == true {
                        var all = [state.contacts, state.placeholders]
                        all[indexPath.section].remove(at: indexPath.row)
                    }
                    _ = ContactCommandsViewModel(contacts: all, placeholders: state.placeholders)
                    
                })
                .disposed(by: disposeBag)
            return ContactCommandsViewModel(contacts: all, placeholders: state.placeholders)
        }
        
    }
}

enum ContactCommand {
    case setContacts(contacts: [ContactViewModel])
    case setPlaceholders(placeholders: [ContactViewModel])
    case deleteContact(indexPath: IndexPath)
    case moveContact(from: IndexPath, to: IndexPath)
}

class ContactMainViewController: UIViewController, UITableViewDelegate {

    var disposeBag = DisposeBag()

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet var searchBar: UISearchBar!

    var dataSource = ContactMainViewController.configureDataSource()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = 67
        tableView.hideEmptyCells()
        tableView.allowsSelectionDuringEditing = true

        
        tableView.register(UINib(nibName: "ContactSearchCell", bundle: nil), forCellReuseIdentifier: "ContactSearchCell")

        self.navigationItem.rightBarButtonItem = self.editButtonItem

        guard let searchBar = self.searchBar else {
            return
        }
        searchBar.autocapitalizationType = .none

        let REST = DefaultContactREST.instance

        let loadContacts = searchBar.rx.text.orEmpty
            .asDriver()
            .throttle(0.3)
            .distinctUntilChanged()
            .flatMapLatest { query in
                REST.searchContacts(query)
                    .retry(3)
                    .retryOnBecomesReachable([], reachabilityService: Factory.instance.reachabilityService)
                    .startWith([]) // clears results on new search term
                    .asDriver(onErrorJustReturn: [])
            }
            .map { results in
                return results.map(ContactViewModel.init)
            }
            .map(ContactCommand.setContacts)


        tableView.rx.contentOffset
            .asDriver()
            .drive(onNext: { _ in
                if searchBar.isFirstResponder {
                    _ = searchBar.resignFirstResponder()
                }
            })
            .disposed(by: disposeBag)
        
        let contactViewModel = ContactViewModel(contact: Contact(id: nil, first: "", last: "", dob: "", phone: "", zip: 0))
        
        let initialLoadCommand = Observable.just(ContactCommand.setPlaceholders(placeholders: [contactViewModel])).concat(loadContacts)
            .observeOn(MainScheduler.instance)

//        let initialLoadCommand = Observable.just(ContactCommand.setContacts(contacts: [contactViewModel]))
//                .concat(loadContacts)
//                .observeOn(MainScheduler.instance)


//        let insertContactCommand = tableView.rx.itemInserted.map(ContactCommand.insertContact)
        let moveContactCommand = tableView
            .rx.itemMoved
            .map(ContactCommand.moveContact)

        let deleteContactCommand = tableView.rx.itemDeleted.map(ContactCommand.deleteContact)
        let initialState = ContactCommandsViewModel(contacts: [], placeholders: [])

        let viewModel =  Observable.system(
            initialState,
            accumulator: ContactCommandsViewModel.executeCommand,
            scheduler: MainScheduler.instance,
            feedback: { _ in initialLoadCommand }, { _ in deleteContactCommand }, { _ in moveContactCommand } )
            .shareReplay(1)

        viewModel
            .asObservable()
            .map {
                [
                    SectionModel(model: "Contacts", items: $0.contacts),
                    SectionModel(model: "", items: [contactViewModel])
                ]
            }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        tableView.rx.itemSelected
            .withLatestFrom(viewModel) { i, viewModel in
                if i.section == 1 {
                    return ContactViewModel(contact: Contact(id: nil, first: "", last: "", dob: "", phone: "", zip: 0))
                }
                let all = [viewModel.contacts]
                return all[i.section][i.row]
            }
            .subscribe(onNext: { [weak self] contact in
                self?.showEditionForContact(contact)
            })
            .disposed(by: disposeBag)

        tableView.rx.itemInserted
            .withLatestFrom(viewModel) { i, viewModel in
                return ContactViewModel(contact: Contact(id: nil, first: "", last: "", dob: "", phone: "", zip: 0))
            }
            .subscribe(onNext: { [weak self] contact in
                self?.showEditionForContact(contact)
            })
            .disposed(by: disposeBag)

        tableView.rx.setDelegate(self)
            .disposed(by: disposeBag)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.isEditing = editing
        tableView.reloadData()
    }
    
    private func showEditionForContact(_ contact: ContactViewModel? = nil) {
        self.performSegue(withIdentifier: "ContactEditionViewController", sender: contact)
    }

    // MARK: Work over Variable

    static func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, ContactViewModel>> {
        let dataSource = RxTableViewSectionedReloadDataSource<SectionModel<String, ContactViewModel>>()

        dataSource.configureCell = { (_, tv, ip, contact: ContactViewModel) in
            let cell = tv.dequeueReusableCell(withIdentifier: "ContactSearchCell") as! ContactSearchCell
            cell.viewModel = contact
            return cell
        }

        dataSource.titleForHeaderInSection = { dataSource, sectionIndex in
            return dataSource[sectionIndex].model
        }

        dataSource.canEditRowAtIndexPath = { (ds, ip) in
            return true
        }

        return dataSource
    }
    

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        if self.isEditing {
            if indexPath.section == 1 {
                return .insert
            }
        }
        return .delete
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? ContactEditionViewController {
            viewController.viewModel = sender as? ContactViewModel
        }
    }
    
    
    
}
