//
// ChannelListViewController.swift
// CloudFirestoreStubPOC
//
// Copyright (c) 2017 Hironori Ichimiya <hiron@hironytic.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import UIKit
import RxSwift
import RxCocoa

public class ChannelListViewController: UITableViewController {
    public var viewModel: ChannelListViewModel?
    private var _disposeBag: DisposeBag?

    public override func viewDidLoad() {
        super.viewDidLoad()
        guard ProcessInfo.processInfo.environment["TESTING"] == nil else { return }
        
        viewModel = defaultResolver.resolveChannelListViewModel()
        bindViewModel()
    }
    
    private func bindViewModel() {
        _disposeBag = nil
        
        guard let viewModel = viewModel else { return }
        
        let disposeBag = DisposeBag()

        tableView.dataSource = nil
        viewModel.channels
            .bind(to: tableView.rx.items(cellIdentifier: "Cell")) { (row, element, cell) in
                cell.textLabel?.text = element.name
            }
            .disposed(by: disposeBag)

        _disposeBag = disposeBag
    }


    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    public override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let cell = sender as! UITableViewCell
        let indexPath = tableView.indexPath(for: cell)!
        let item: ChannelListItem = try! tableView.rx.model(at: indexPath)
        let messageViewModel = defaultResolver.resolveMessageViewModel(channelID: item.channelID)
        (segue.destination as! MessageViewController).viewModel = messageViewModel
    }
}

public struct ChannelListItem {
    let channelID: String
    let name: String
}

public protocol ChannelListViewModel {
    var channels: Observable<[ChannelListItem]> { get }
}

public protocol ChannelListViewModelResolver {
    func resolveChannelListViewModel() -> ChannelListViewModel
}

extension DefaultResolver: ChannelListViewModelResolver {
    public func resolveChannelListViewModel() -> ChannelListViewModel {
        return DefaultChannelListViewModel(resolver: self)
    }
}

public class DefaultChannelListViewModel: ChannelListViewModel {
    public typealias Resolver = DataStoreResolver
    
    public let channels: Observable<[ChannelListItem]>
    
    public init(resolver: Resolver) {
        let dataStore = resolver.resolveDataStore()
        let query = dataStore
            .collection("channels")
            .whereField("public", isEqualTo: true)
            .order(by: "name")
        
        channels = dataStore
            .observeCollection(matches: query)
            .map { $0.map { document in
                let name = document.data["name"] as? String ?? ""
                return ChannelListItem(channelID: document.documentID, name: name)
            }}
            .do(onError: { error in
                print("error   ---- \(error)")
            })
            .catchErrorJustReturn([])
            .observeOn(MainScheduler.instance)
    }
}
