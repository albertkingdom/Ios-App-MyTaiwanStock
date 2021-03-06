//
//  Observable.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/15/22.
//

import Foundation

class Observable<T> {

    typealias Listener = (T?) -> Void

    init(_ value: T?) {
        self.value = value
    }

    var value: T? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.listener?(self?.value)
            }
        }
    }

    var listener: Listener?

    func bind(to listener: @escaping Listener) {
        self.listener = listener
        DispatchQueue.main.async { [weak self] in
            listener(self?.value)
        }
    }

}
