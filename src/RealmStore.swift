//
//  RealmStore.swift
//  MyApp
//
//  Created by Eloi Guzmán Cerón on 28/11/16.
//  Copyright © 2016 Worldline. All rights reserved.
//

import UIKit
import RealmSwift
import T21SortingDescriptorSwift

typealias PrimaryKey = String
typealias NumberPrimaryKey = Int


public class RealmStore {
    
    private var queue = OperationQueue()
    private var configuration: Realm.Configuration? = nil
    
    public init(_ configuration: Realm.Configuration? = nil) {
        queue.maxConcurrentOperationCount = 1
        self.configuration = configuration
    }
    
    public func read(_ readClosure: @escaping (_ realm: Realm) -> (Void), _ completionClosure: @escaping (_ realm: Realm) -> (Void)) {
        read(readClosure, completionClosure, self.queue)
    }
    
    public func read(_ readClosure: @escaping (_ realm: Realm) -> (Void), _ completionClosure: @escaping (_ realm: Realm) -> (Void), _ queue: OperationQueue) {
        let innerReadFunction = { (realm: Realm) -> (Void) in
            readClosure(realm)
        }
        let innerCompletionFunction = { (realm: Realm) -> (Void) in
            completionClosure(realm)
        }
        read(innerReadFunction, innerCompletionFunction,queue)
    }
    
    public func read<ResultFromBackgroundThread>(_ readClosure: @escaping (_ realm: Realm) -> (ResultFromBackgroundThread), _ completionClosure: @escaping ( _ result: RealmStoreResult<ResultFromBackgroundThread>) -> (Void)) {
        read(readClosure, completionClosure,self.queue)
    }
    
    public func read<ResultFromBackgroundThread>(_ readClosure: @escaping (_ realm: Realm) -> (ResultFromBackgroundThread), _ completionClosure: @escaping ( _ result: RealmStoreResult<ResultFromBackgroundThread>) -> (Void), _ queue: OperationQueue) {
        let currentQueue = OperationQueue.current!
        queue.addOperation{
            do {
                let r = try self.realm()
                r.refresh()
                let result: ResultFromBackgroundThread = readClosure(r)
                currentQueue.addOperation {
                    do {
                        let r = try self.realm()
                        r.refresh()
                        completionClosure(RealmStoreResult.success(result: result, realm: r))
                    } catch let error {
                        completionClosure(RealmStoreResult.failure(RealmStoreError.uninitializedStore(error: error)))
                        NSLog("RealmStore can't get the Realm instance: \(error) ")
                    }
                }
            } catch let error {
                NSLog("RealmStore can't get the Realm instance: \(error) ")
            }
        }
    }
    
    public func write(_ writeClosure: @escaping (_ realm: Realm) -> (Void), _ completionClosure: @escaping (RealmStoreResult<Void>) -> (Void)) {
        write(writeClosure, completionClosure,self.queue)
    }
    
    public func write(_ writeClosure: @escaping (_ realm: Realm) -> (Void), _ completionClosure: @escaping (RealmStoreResult<Void>) -> (Void), _ queue: OperationQueue) {
        let innerWriteFunction = { (realm: Realm) -> (Bool) in
            writeClosure(realm)
            return true
        }
        let innerCompletionFunction = { ( result: RealmStoreResult<Bool>) -> (Void) in
            switch result {
            case let .success(_, realm):
                completionClosure(RealmStoreResult.success(result: (), realm: realm))
                break
            case let .failure(error):
                completionClosure(RealmStoreResult.failure(error))
                break
            }
        }
        write(innerWriteFunction, innerCompletionFunction)
    }
    
    public func write<ResultFromBackgroundThread>(_ writeClosure: @escaping (_ realm: Realm) -> (ResultFromBackgroundThread), _ completionClosure: @escaping ( _ result: RealmStoreResult<ResultFromBackgroundThread>) -> (Void)) {
        write(writeClosure, completionClosure,self.queue)
    }
    
    public func write<ResultFromBackgroundThread>(_ writeClosure: @escaping (_ realm: Realm) -> (ResultFromBackgroundThread), _ completionClosure: @escaping ( _ result: RealmStoreResult<ResultFromBackgroundThread>) -> (Void), _ queue: OperationQueue) {
        let currentQueue = OperationQueue.current!
        queue.addOperation {
            do {
                let r = try self.realm()
                r.refresh()
                
                let wasInWriteTransaction = r.isInWriteTransaction
                if !wasInWriteTransaction {
                    r.beginWrite()
                }
                
                let result: ResultFromBackgroundThread = writeClosure(r)
                
                if !wasInWriteTransaction {
                    do {
                        try r.commitWrite()
                        currentQueue.addOperation {
                            do {
                                let realm = try self.realm()
                                realm.refresh()
                                completionClosure(RealmStoreResult.success(result: result, realm: realm))
                            } catch let error {
                                RealmStoreLogger.error("Can't get the Realm instance: \(error) ")
                                completionClosure(RealmStoreResult.failure(RealmStoreError.uninitializedStore(error: error)))
                            }
                        }
                    } catch let error {
                        RealmStoreLogger.error("Commit transaction failed: \(error) ")
                        currentQueue.addOperation {
                            completionClosure(RealmStoreResult.failure(RealmStoreError.saveError(error: error)))
                        }
                    }
                }
            } catch let error {
                RealmStoreLogger.error("Can't get the Realm instance: \(error) ")
                currentQueue.addOperation {
                    completionClosure(RealmStoreResult.failure(RealmStoreError.uninitializedStore(error: error)))
                }
            }
        }
    }
    
    open func realm() throws -> Realm {
        do {
            if let conf = self.configuration {
                return try Realm(configuration: conf)
            } else {
                return try Realm()
            }
        } catch let error {
            RealmStoreLogger.error("Loading Realm stack failed: \(error) ")
            throw error
        }
    }

    
    //MARK: Querying Helpers
    public static func getObjects<ClassType : Object,KeyType>(_ realm: Realm, _ primaryKeys: Array<KeyType>) -> Array<ClassType> {
        return getObjects(realm, primaryKeys, nil, nil)
    }
    
    public static func getObjects<ClassType : Object,KeyType>(_ realm: Realm, _ primaryKeys: Array<KeyType>, _ predicateFunction: ((ClassType) -> (Bool))?) -> Array<ClassType> {
        return getObjects(realm, primaryKeys, predicateFunction, nil)
    }
    
    public static func getObjects<ClassType : Object,KeyType>(_ realm: Realm, _ primaryKeys: Array<KeyType>, _ predicateFunction: ((ClassType) -> (Bool))?, _ sortingDescriptors: [T21SortingDescriptorSwift.SortDescriptor<ClassType>]?) -> Array<ClassType> {
        return realm.getObjects(primaryKeys, predicateFunction, sortingDescriptors)
    }
    
    public static func getAllObjects<ClassType: Object>(_ realm: Realm) -> Array<ClassType> {
            return getAllObjects(realm, nil, nil)
    }
    
    public static func getAllObjects<ClassType: Object>(_ realm: Realm, _ predicate: NSPredicate?) -> Array<ClassType> {
        return getAllObjects(realm, predicate, nil)
    }
    
    public static func getAllObjects<ClassType: Object>(_ realm: Realm, _ predicate: NSPredicate?, _ sortingDescriptors: [RealmSwift.SortDescriptor]?) -> Array<ClassType> {
        return realm.getAllObjects(predicate, sortingDescriptors)

    }
    
    public static func getAllObjects<ClassType: Object>(_ realm: Realm) -> RealmSwift.Results<ClassType>? {
        return getAllObjects(realm, nil, nil)
    }
    
    public static func getAllObjects<ClassType: Object>(_ realm: Realm, _ predicate: NSPredicate?) -> RealmSwift.Results<ClassType>? {
        return getAllObjects(realm, predicate, nil)
    }
    
    public static func getAllObjects<ClassType: Object>(_ realm: Realm, _ predicate: NSPredicate?, _ sortingDescriptors: [RealmSwift.SortDescriptor]?) -> RealmSwift.Results<ClassType>? {
        return realm.getAllObjects(predicate, sortingDescriptors)
    }
    
    //MARK: Insert and update helpers
    public static func getOrCreateObject<ClassType: Object,KeyType>(_ realm: Realm, _ primaryKey: KeyType? = nil) -> ClassType {
        return realm.getOrCreateObject(primaryKey)
    }
    
    public func getUniqueInstanceObject<ClassType: Object>(_ realm: Realm) -> ClassType {
        return realm.getUniqueInstanceObject()
    }
    
    
    //MARK: Primary key helpers
    public static func getPrimaryKeys<ClassType: Object, KeyType>(_ objects: Array<ClassType>) -> Array<KeyType> {
        var pk = Array<KeyType>()
        pk.reserveCapacity(objects.count)
        for o in objects {
            if let p: KeyType = o.getPrimaryKey() {
                pk.append(p)
            }
        }
        return pk
    }
    
    public static func getPrimaryKeys<ClassType, KeyType>(_ objects: RealmSwift.Results<ClassType>) -> Array<KeyType> {
        var pk = Array<KeyType>()
        pk.reserveCapacity(objects.count)
        for o in objects {
            if let p: KeyType = o.getPrimaryKey() {
                pk.append(p)
            }
        }
        return pk
    }
}

extension RealmSwift.Realm {
       
    public func getObjects<ClassType : Object,KeyType>( _ primaryKeys: Array<KeyType>) -> Array<ClassType> {
        return getObjects(primaryKeys, nil, nil)
    }
    
    public func getObjects<ClassType : Object,KeyType>( _ primaryKeys: Array<KeyType>, _ predicateFunction: ((ClassType) -> (Bool))?) -> Array<ClassType> {
        return getObjects(primaryKeys, predicateFunction, nil)
    }
    
    public func getObjects<ClassType : Object,KeyType>( _ primaryKeys: Array<KeyType>, _ predicateFunction: ((ClassType) -> (Bool))?, _ sortingDescriptors: [T21SortingDescriptorSwift.SortDescriptor<ClassType>]?) -> Array<ClassType> {
            var objects = Array<ClassType>()
            objects.reserveCapacity(primaryKeys.count)
            for pk in primaryKeys {
                if let obj = self.object(ofType: ClassType.self, forPrimaryKey: pk) {
                    objects.append(obj)
                }
            }
            
            if let predicate = predicateFunction {
                objects = objects.filter(predicate)
            }
            
            if let descriptors = sortingDescriptors {
                objects.sort(by: CombineSortDescriptors(sortDescriptors: descriptors))
            }
            
            return objects
    }
    
    public func getAllObjects<ClassType: Object>() -> Array<ClassType> {
        return getAllObjects(nil, nil)
    }
    
    public func getAllObjects<ClassType: Object>( _ predicate: NSPredicate?) -> Array<ClassType> {
        return getAllObjects(predicate, nil)
    }
    
    public func getAllObjects<ClassType: Object>( _ predicate: NSPredicate?, _ sortingDescriptors: [RealmSwift.SortDescriptor]?) -> Array<ClassType> {
        if let results: Results<ClassType> = getAllObjects(predicate, sortingDescriptors) {
            return results.toArray()
        }
        return []
    }
    
    public func getAllObjects<ClassType: Object>() -> RealmSwift.Results<ClassType>? {
        return getAllObjects(nil, nil)
    }
    
    public func getAllObjects<ClassType: Object>( _ predicate: NSPredicate?) -> RealmSwift.Results<ClassType>? {
        return getAllObjects(predicate, nil)
    }
    
    public func getAllObjects<ClassType: Object>( _ predicate: NSPredicate?, _ sortingDescriptors: [RealmSwift.SortDescriptor]?) -> RealmSwift.Results<ClassType>? {
        
        var objects = self.objects(ClassType.self)
        
        if let p = predicate {
            objects = objects.filter(p)
        }
        
        if let s = sortingDescriptors {
            objects = objects.sorted(by: s)
        }
        
        return objects
    }
    
    public func getOrCreateObject<ClassType: Object,KeyType>(_ primaryKey: KeyType? = nil) -> ClassType {
        if let pk = primaryKey {
            if let prevObj = self.object(ofType: ClassType.self, forPrimaryKey: primaryKey) {
                return prevObj
            } else {
                let newObj = ClassType()
                newObj.setPrimaryKey(pk)
                self.add(newObj)
                return newObj
            }
        } else {
            let newObj = ClassType()
            self.add(newObj)
            return newObj
        }
    }
    
    public func getUniqueInstanceObject<ClassType: Object>() -> ClassType {
        let object: ClassType? = self.objects(ClassType.self).first
        if let obj = object {
           return obj
        } else {
            let newObj = ClassType()
            self.add(newObj)
            return newObj
        }
    }
}

extension RealmSwift.Object {
    public func getPrimaryKey<KeyType>() -> KeyType? {
        if let pk = type(of: self).primaryKey() {
            return self[pk] as! KeyType?
        } else {
            return nil
        }
    }
    
    public func setPrimaryKey<KeyType>(_ primaryKey: KeyType) {
        if let pk = type(of: self).primaryKey() {
            self[pk] = primaryKey
        }
    }
}

extension RealmSwift.Results {

    public func toArray() -> Array<T> {
        var objects = Array<T>()
        objects.reserveCapacity(self.count)
        for o in self {
            objects.append(o)
        }
        return objects
    }
}


