//
// MessageViewController.swift
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

public class MessageViewController: UITableViewController {
    public var viewModel: MessageViewModel?
    private var _disposeBag: DisposeBag?

    public override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = 90
        bindViewModel()
    }

    private func bindViewModel() {
        _disposeBag = nil
        
        guard let viewModel = viewModel else { return }
        
        let disposeBag = DisposeBag()
        
        tableView.dataSource = nil
        viewModel.items
            .bind(to: tableView.rx.items(cellIdentifier: "Cell", cellType: MessageItemCell.self)) { (row, element, cell) in
                cell.fromLabel?.text = element.from
                cell.messageLabel?.text = element.message
            }
            .disposed(by: disposeBag)
        
        _disposeBag = disposeBag
    }
}

public class MessageItemCell: UITableViewCell {
    @IBOutlet weak var fromLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
}

public struct  MessageItem {
    public let from: String
    public let message: String
}

public protocol MessageViewModel {
    var items: Observable<[MessageItem]> { get }
}

public protocol MessageViewModelResolver {
    func resolveMessageViewModel(channelID: String) -> MessageViewModel
}

extension DefaultResolver: MessageViewModelResolver {
    public func resolveMessageViewModel(channelID: String) -> MessageViewModel {
        return DefaultMessageViewModel(resolver: self, channelID: channelID)
    }
}

public class DefaultMessageViewModel: MessageViewModel {
    public typealias Resolver = DataStoreResolver
    
    public let items: Observable<[MessageItem]>
    
    public init(resolver: Resolver, channelID: String) {
        let dataStore = resolver.resolveDataStore()
        let query = dataStore
            .collection("channels")
            .document(channelID)
            .collection("messages")
            .order(by: "timestamp")
        
        items = dataStore
            .observeCollection(matches: query)
            .map { $0.map { document in
                let data = document.data
                let from = data["from"] as? String ?? ""
                let message = data["message"] as? String ?? ""
                return MessageItem(from: from, message: message)
            }}
            .do(onError: { error in
                print("error   ---- \(error)")
            })
            .catchErrorJustReturn([])
            .observeOn(MainScheduler.instance)
    }
}
