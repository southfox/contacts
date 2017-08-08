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

    static func sanity(state: ContactCommandsViewModel) -> [[ContactViewModel]] {
        var all = [state.contacts, state.placeholders]
        while all[1].count > 0 {
            if let vm = all[1].popLast(),
                vm.contact.id != nil
            {
                all[0].append(vm)
            }
        }
        return all
    }
    static func executeCommand(state: ContactCommandsViewModel, _ command: ContactCommand) -> ContactCommandsViewModel {
        switch command {
        case .reloadContacts():
            let all = sanity(state: state)
            return ContactCommandsViewModel(contacts: all[0], placeholders: all[1])
        case let .setContacts(contacts):
            var all = sanity(state: state)
            all[0] = contacts
            return ContactCommandsViewModel(contacts: all[0], placeholders: all[1])
        case let .setPlaceholders(placeholders):
            var all = sanity(state: state)
            all[1] = placeholders
            return ContactCommandsViewModel(contacts: all[0], placeholders: all[1])
        case .insertContact(_):
            var all = sanity(state: state)
            let cvm = ContactViewModel(contact: Contact(id: nil, first: "", last: "", dob: "", phone: "", zip: 0))
            all[0].append(cvm)
            return ContactCommandsViewModel(contacts: all[0], placeholders: all[1])

        case let .insertOnSelectContact(indexPath):
            var all = sanity(state: state)
            if indexPath.section == 1 {
                let cvm = ContactViewModel(contact: Contact(id: nil, first: "", last: "", dob: "", phone: "", zip: 0))
                all[0].append(cvm)
            }
            return ContactCommandsViewModel(contacts: all[0], placeholders: all[1])

        case let .deleteContact(indexPath):
            var all = sanity(state: state)
            let disposeBag = DisposeBag()
            let contact = all[indexPath.section][indexPath.row]
            DefaultContactREST.instance.deleteContact(id: contact.contact.id)
                .retry(3)
                .retryOnBecomesReachable(false, reachabilityService: Factory.instance.reachabilityService)
                .subscribe({ (event) in
                    if event.element == true {
                        // TODO: here!!!!
                    }
                    _ = ContactCommandsViewModel(contacts: all[0], placeholders: all[1])
                })
                .disposed(by: disposeBag)
            all[indexPath.section].remove(at: indexPath.row)
            return ContactCommandsViewModel(contacts: all[0], placeholders: all[1])
        }
    }
}

enum ContactCommand {
    case setContacts(contacts: [ContactViewModel])
    case reloadContacts()
    case setPlaceholders(placeholders: [ContactViewModel])
    case deleteContact(indexPath: IndexPath)
    case insertContact(indexPath: IndexPath)
    case insertOnSelectContact(indexPath: IndexPath)
}

class ContactMainViewController: UIViewController, UITableViewDelegate {

    var disposeBag = DisposeBag()

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet var searchBar: UISearchBar!

    var dataSource = ContactMainViewController.configureDataSource()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
        
        let subject = PublishSubject<String>()
        subject.on(.next("reload"))
        
        subject.subscribe {
            print($0)
            }
            .addDisposableTo(disposeBag)


        searchBar.autocapitalizationType = .none
        let REST = DefaultContactREST.instance

        let loadContacts = searchBar.rx.text.orEmpty
            .asDriver()
            .throttle(0.3)
            .distinctUntilChanged()
            .asObservable()
            .shareReplay(1)
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

        searchBar.rx.searchButtonClicked.subscribe { (event) in
            print(event)
        }
        .disposed(by: disposeBag)
        
        tableView.rx.contentOffset
            .asDriver()
            .drive(onNext: { [weak self] _ in
                self?.tableView.reloadData()
                if searchBar.isFirstResponder {
                    _ = searchBar.resignFirstResponder()
                }
            })
            .disposed(by: disposeBag)
        
        let contactViewModel = ContactViewModel(contact: Contact(id: nil, first: "", last: "", dob: "", phone: "", zip: 0))
        
        let initialState = ContactCommandsViewModel(contacts: [], placeholders: [])
        
        let initialLoadCommand = Observable.just(ContactCommand.setPlaceholders(placeholders: [])).concat(loadContacts)
            .observeOn(MainScheduler.instance)

        let insertContactCommand = tableView.rx.itemInserted.map(ContactCommand.insertContact)
        
        let selectContactCommand = tableView.rx.itemSelected.map(ContactCommand.insertOnSelectContact)
        
        let deleteContactCommand = tableView.rx.itemDeleted.map(ContactCommand.deleteContact)

        let viewModel =  Observable.system(
            initialState,
            accumulator: ContactCommandsViewModel.executeCommand,
            scheduler: MainScheduler.instance,
            feedback: { _ in initialLoadCommand }, { _ in deleteContactCommand }, { _ in selectContactCommand }, { _ in insertContactCommand } )
            .shareReplay(1)

        viewModel
            .asObservable()
            .map {
                [
                    SectionModel(model: "Contacts", items: $0.contacts),
                    SectionModel(model: "", items: [contactViewModel])
                ]
            }
            .do(onNext: { (smcvm) in
                print("here")
            })
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        tableView.rx.itemSelected
            .withLatestFrom(viewModel) { i, viewModel in
                let all = viewModel.contacts
                if i.section == 1 {
                    return all.last
                }
                return all[i.row]
            }
            .subscribe(onNext: { [weak self] contact in
                self?.showEditionForContact(contact)
            })
            .disposed(by: disposeBag)

        tableView.rx.itemInserted
            .withLatestFrom(viewModel) { i, viewModel in
                let all = viewModel.contacts
                return all.last
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
//            viewController.updateBlock = {
////                viewController.viewModel?.contact
//            }
        }
    }
    
    
    
}
