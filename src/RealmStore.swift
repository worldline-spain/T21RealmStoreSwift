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

public class RealmStore {
    
    private var queue = OperationQueue()
    private var configuration: Realm.Configuration? = nil
    
    public init(_ configuration: Realm.Configuration? = nil) {
        queue.maxConcurrentOperationCount = 1
        self.configuration = configuration
    }
    
    public func executeReadRealmBlock(_ readFunction: @escaping (_ realm: Realm) -> (Void), _ completionFunction: @escaping (_ realm: Realm) -> (Void)) {
            executeReadRealmBlock(readFunction, completionFunction, self.queue)
    }
    
    public func executeReadRealmBlock(_ readFunction: @escaping (_ realm: Realm) -> (Void), _ completionFunction: @escaping (_ realm: Realm) -> (Void), _ queue: OperationQueue) {
        let innerReadFunction = { (realm: Realm) -> (Void) in
            readFunction(realm)
        }
        let innerCompletionFunction = { (realm: Realm) -> (Void) in
            completionFunction(realm)
        }
        executeReadRealmBlock(innerReadFunction, innerCompletionFunction,queue)
    }
    
    public func executeReadRealmBlock<BackgroundResultType>(_ readFunction: @escaping (_ realm: Realm) -> (BackgroundResultType), _ completionFunction: @escaping (_ realm: Realm, _ results: BackgroundResultType) -> (Void)) {
        self.executeReadRealmBlock(readFunction, completionFunction,self.queue)
    }
    
    public func executeReadRealmBlock<BackgroundResultType>(_ readFunction: @escaping (_ realm: Realm) -> (BackgroundResultType), _ completionFunction: @escaping (_ realm: Realm, _ results: BackgroundResultType) -> (Void), _ queue: OperationQueue) {
        let currentQueue = OperationQueue.current!
        queue.addOperation {
            let r = self.getRealm()
            r.refresh()
            let result: BackgroundResultType = readFunction(r)
            currentQueue.addOperation {
                let realm = self.getRealm()
                realm.refresh()
                completionFunction(realm,result)
            }
        }
    }
    
    public func executeWriteRealmBlock(_ writeFunction: @escaping (_ realm: Realm) -> (Void), _ completionFunction: @escaping (_ realm: Realm, _ error: Error?) -> (Void)) {
        executeWriteRealmBlock(writeFunction, completionFunction,self.queue)
    }
    
    public func executeWriteRealmBlock(_ writeFunction: @escaping (_ realm: Realm) -> (Void), _ completionFunction: @escaping (_ realm: Realm, _ error: Error?) -> (Void), _ queue: OperationQueue) {
        let innerWriteFunction = { (realm: Realm) -> (RealmStoreResult<Bool>) in
            writeFunction(realm)
            return RealmStoreResult.success(true)
        }
        let innerCompletionFunction = { (realm: Realm, result: RealmStoreResult<Bool>) -> (Void) in
           completionFunction(realm,result.error)
        }
        executeWriteRealmBlock(innerWriteFunction, innerCompletionFunction)
    }
    
    public func executeWriteRealmBlock<BackgroundResultType>(_ writeFunction: @escaping (_ realm: Realm) -> (RealmStoreResult<BackgroundResultType>), _ completionFunction: @escaping (_ realm: Realm, _ results: RealmStoreResult<BackgroundResultType>) -> (Void)) {
        executeWriteRealmBlock(writeFunction, completionFunction,self.queue)
    }
    
    public func executeWriteRealmBlock<BackgroundResultType>(_ writeFunction: @escaping (_ realm: Realm) -> (RealmStoreResult<BackgroundResultType>), _ completionFunction: @escaping (_ realm: Realm, _ results: RealmStoreResult<BackgroundResultType>) -> (Void), _ queue: OperationQueue) {
        let currentQueue = OperationQueue.current!
        queue.addOperation {
            let r = self.getRealm()
            r.refresh()

            let wasInWriteTransaction = r.isInWriteTransaction
            if !wasInWriteTransaction {
                r.beginWrite()
            }
            
            var result: RealmStoreResult<BackgroundResultType> = writeFunction(r)
            
            if !wasInWriteTransaction {
                do {
                    try r.commitWrite()
                } catch {
                    result = RealmStoreResult.failure(RealmStoreError.saveError)
                }
            }
            
            currentQueue.addOperation {
                let realm = self.getRealm()
                realm.refresh()
                completionFunction(realm,result)
            }
        }
    }
    
    open func getRealm() -> Realm {
        var r: Realm? = nil
        do {
            if let conf = self.configuration {
                r = try Realm.init(configuration: conf)
            } else {
                r = try Realm.init()
            }
        } catch {
            //todo: change with a proper logger tool
            NSLog("ERROR: loading Realm stack")
        }
        return r! //todo: this can cause a crash... change getRealm to throwable function?
        //if we make this function throwable, every executeReadBlock & executeWriteBlock will be throwable too
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
    
    public static func getPrimaryKeys<ClassType: Object, KeyType>(_ objects: RealmSwift.Results<ClassType>) -> Array<KeyType> {
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
                objects.sort(by: combine(sortDescriptors: descriptors))
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


