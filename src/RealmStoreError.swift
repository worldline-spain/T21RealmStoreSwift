//
//  RealmStoreError.swift
//  RealmStore
//
//  Created by Eloi Guzmán Cerón on 08/08/2017.
//  Copyright © 2017 Worldline. All rights reserved.
//

import Foundation

public enum RealmStoreError : Error {
    case saveError(error: Error)
    case uninitializedStore(error: Error)
    case other(error: Error)
}
