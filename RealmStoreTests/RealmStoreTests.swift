//
//  RealmStoreTests.swift
//  RealmStoreTests
//
//  Created by Eloi Guzmán Cerón on 11/01/17.
//  Copyright © 2017 Worldline. All rights reserved.
//

import XCTest
@testable import RealmStore
@testable import RealmSwift

class RealmStoreTests: XCTestCase {

    let realmStore = RealmStore()
    
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
        self.realmStore.getRealm().beginWrite()
        self.realmStore.getRealm().deleteAll()
        try? self.realmStore.getRealm().commitWrite()
    }
    
    func testInsertNewObjectsToTheDB() {
        
        let expectation = self.expectation(description: "Realm Transaction")

        realmStore.executeWriteRealmBlock({ (realm) -> (Void) in
            
            //this part is executed in a background thread
            var user: User = realm.getOrCreateObject("A")
            user.name = "Name A"
            
            user = realm.getOrCreateObject("B")
            user.name = "Name B"
            
            user = realm.getOrCreateObject("C")
            user.name = "Name C"

            user = realm.getOrCreateObject("D")
            user.name = "Name D"
            
        },{(realm, error) -> (Void) in
            expectation.fulfill()
            
            //this part is executed in the calling thread (usually the main thread)
            //the following call fecth ALL the User objects from the DB
            if error == nil {
                let users: [User] = realm.getAllObjects()
                print(users)
                XCTAssert(users.count == 4)
            } else {
                XCTFail()
            }
        })
        
        self.waitForExpectations(timeout: 0.5, handler: nil)
    }
    
    func testInsertNewObjectsToTheDB2() {
        
        let expectation = self.expectation(description: "Realm Transaction")
        
        realmStore.executeWriteRealmBlock({ (realm) -> (RealmStoreResult<[String]>) in
            
            //this part is executed in a background thread
            var newUsersAdded = [User]()
            var user: User = realm.getOrCreateObject("A")
            user.name = "Name A"
            newUsersAdded.append(user)
            
            user = realm.getOrCreateObject("B")
            user.name = "Name B"
            newUsersAdded.append(user)
            
            user = realm.getOrCreateObject("C")
            user.name = "Name C"
            newUsersAdded.append(user)
            
            user = realm.getOrCreateObject("D")
            user.name = "Name D"
            newUsersAdded.append(user)
            
            //we accumulate the primary keys into an array, to perform
            let primaryKeys: [String] = RealmStore.getPrimaryKeys(newUsersAdded)
            
            //we send the resulting primary keys to the calling thread block
            return RealmStoreResult.success(primaryKeys)
            
        },{(realm, results) -> (Void) in
            expectation.fulfill()
            // this part is executed in the calling thread (usually the main thread)
            // the following call fecth only the previously inserted Users in a background thread write block.
            // to fetch them it uses the results primary key's array from the background block
            
            //check if the save was done properly
            if results.isSuccess {
                let users: [User] = realm.getObjects(results.value!)
                print(users)
                XCTAssert(users.count == 4)
            } else {
                XCTFail()
            }
        })
        
        self.waitForExpectations(timeout: 0.5, handler: nil)
    }
    
    func testReadNewObjectsFromTheDB() {
        
        let expectation = self.expectation(description: "Realm Transaction")
        
        //add objects first
        realmStore.executeWriteRealmBlock({ (realm) -> (Void) in
            
            //this part is executed in a background thread
            var user: User = realm.getOrCreateObject("A")
            user.name = "Name A"
            user = realm.getOrCreateObject("B")
            user.name = "Name B"
            user = realm.getOrCreateObject("C")
            user.name = "Name C"
            user = realm.getOrCreateObject("D")
            user.name = "Name D"
        },{(realm, error) -> (Void) in
            
            //this part is executed in the calling thread (usually the main thread)
            //the following call fecth ALL the User objects from the DB
            if error == nil {
                let users: [User] = realm.getAllObjects()
                print(users)
                XCTAssert(users.count == 4)
                
                //test the READ operation now
                self.realmStore.executeReadRealmBlock({ (realm) -> ([String]) in
                    
                    //assume this is a complex query with a complex predicate
                    let predicate = NSPredicate(format: "(name CONTAINS %@) OR (name CONTAINS %@)", "C", "D")
                    let objects: [User] = realm.getAllObjects(predicate)
                    
                    //we accumulate the primary keys into an array, to perform
                    let primaryKeys: [String] = RealmStore.getPrimaryKeys(objects)
                    
                    //we send the resulting primary keys to the calling thread block
                    return primaryKeys
                },{(realm, results) -> (Void) in
                    expectation.fulfill()
                    // this part is executed in the calling thread (usually the main thread)
                    // the following call fecth only the previously fetched Users in a background thread write block.
                    // to fetch them it uses the results primary key's array from the background block
                    
                    //check if the save was done properly
                    let users: [User] = realm.getObjects(results)
                    print(users)
                    XCTAssert(users.count == 2) // [User C, User D]
                })
            } else {
                expectation.fulfill()
                XCTFail()
            }
        })
        
        self.waitForExpectations(timeout: 0.5, handler: nil)
    }
    
}


public class User : Object {
    dynamic var name: String = ""
    dynamic var uid: String = ""
    
    override public static func primaryKey() -> String? {
        return "uid"
    }
}
