//
//  RealmStoreResult.swift
//  RealmStore
//
//  Created by Eloi Guzmán Cerón on 11/01/17.
//  Copyright © 2017 Worldline. All rights reserved.
//

import Foundation
import RealmSwift

public enum RealmStoreResult<Value> {
    case success(result: Value, realm: Realm)
    case failure(RealmStoreError)
    
    public var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    public var isFailure: Bool {
        return !isSuccess
    }
    
    public var value: Value? {
        switch self {
        case .success(let value):
            return value.result
        case .failure:
            return nil
        }
    }
    
    public var realm: Realm? {
        switch self {
        case .success(let value):
            return value.realm
        case .failure:
            return nil
        }
    }
    
    public var error: Error? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
}
