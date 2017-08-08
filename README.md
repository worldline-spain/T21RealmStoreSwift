#T21RealmStore

## Version 2.0.0

### Creating a new Realm Store

Each time you create a new RealmStore class, a new Realm class is loaded with the default configuration. By default the constructor uses the default realm configuration so keep in mind that if you don't use an specific configuration it will create instances of the same Realm. 

```
import RealmStore

let realmStore = RealmStore()

//or using a custom RealmConfiguration

let realmStore = RealmStore(Realm.Configuration(fileURL: URL(fileURLWithPath: "DocumentsDirectory/CustomRealmPath", isDirectory: false),
                                                inMemoryIdentifier: nil,
                                                syncConfiguration: nil,
                                                encryptionKey: nil,
                                                readOnly: false,
                                                schemaVersion: 1,
                                                migrationBlock: nil,
                                                deleteRealmIfMigrationNeeded: false,
                                                objectTypes: nil))

```

###Adding new objects to the Realm using a background thread

The RealmStore offers some methods to work with background threads. As you may now, working with Realm in a multi-threading environment involves that any object saved in a thread A has to be fetched again in the thread B in order to be used in the thread B.

A common scenario is performing expensive write or read query operations on a background thread, and then performing a simple fetch on the main thread using only the primary keys in order to improve the final query performance.

The following example shows how to insert some objects to the realm using a block executed in a background thread:

```
public class User : Object {
    dynamic var name: String = ""
    dynamic var uid: String = ""
    
    override public static func primaryKey() -> String? {
        return "uid"
    }
}

```


```
realmStore.write({ (realm) -> (Void) in
    
    //this part is executed in a background thread
    //assume this is a very time consuming task
    var user: User = realm.getOrCreateObject("A")
    user.name = "Name A"
    
    user = realm.getOrCreateObject("B")
    user.name = "Name B"
    
    user = realm.getOrCreateObject("C")
    user.name = "Name C"

    user = realm.getOrCreateObject("D")
    user.name = "Name D"
    
},{(result: RealmStoreResult<Void>) -> (Void) in
    
    //this part is executed in the calling thread (usually the main thread)
    //the following call fecth ALL the User objects from the DB
    if let realm = result.realm {
        let users: [User] = realm.getAllObjects()
        print(users)
    } else {
      		// manage the error
    }
})

```


RealmStore manages the beginning of write transactions internally starting them before the execution of the write block and committing them once this one finishes. As you can see the completion block may receive a RealmStoreResult or an Error object depending of the method used. This result/error encapsulates the possible commit transaction save error, so the client can handle it.

Another important feature is that the RealmStore write blocks can be nested, because it manages if a commit transaction has already started or not.

### Adding new objects to the Realm in a background thread and fetching them in the main thread

The following example is very similar to the previous one, but this time, we will assume that the insertion process is a very expensive operation. Our solution will be to add the new users in a background thread to avoid blocking the main thread and then, fetch all the created objects in the main thread using the primary keys.

```                
realmStore.write({ (realm) -> ([String]) in
    
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
    return primaryKeys
    
},{(result: RealmStoreResult<[String]>) -> (Void) in
    
    // this part is executed in the calling thread (usually the main thread)
    // the following call fecth only the previously inserted Users in a background thread write block.
    // to fetch them it uses the results primary key's array from the background block
    
    //check if the save was done properly
    if let realm = result.realm, let primaryKeys = result.value {
        let users: [User] = realm.getObjects(primaryKeys)
        print(users)
    } else {
    	 // manage the error
    }
})
        
```

At first glance it can seem a little bit stupid having to create the extra array in order to store all the primary keys but don't forget that Realm works very fast performing queries by primary key as they are indexed automatically. Our initial purpose is to avoid performing expensive operations on the main thread keeping a very fast UI (like for example expensive insertions or complex queries).

### Performing a complex query on a background thread

In the case of read operations (querying the DB) RealmStore offers different `read` methods.

The following example shows how to perform a query using the RealmStore.

```
//DB Contains Users with the following names: ["Name A", "Name B", "Name C", "Name D"]

self.realmStore.read({ (realm) -> ([String]) in
    
    //assume this is a complex query with a complex predicate
    let predicate = NSPredicate(format: "(name CONTAINS %@) OR (name CONTAINS %@)", "C", "D")
    let objects: [User] = realm.getAllObjects(predicate)
    
    //we accumulate the primary keys into an array, to perform
    let primaryKeys: [String] = RealmStore.getPrimaryKeys(objects)
    
    //we send the resulting primary keys to the calling thread block
    return primaryKeys
},{(result: RealmStoreResult<[String]>) -> (Void) in
    // this part is executed in the calling thread (usually the main thread)
    // the following call fecth only the previously fetched Users in a background thread write block.
    // to fetch them it uses the results primary key's array from the background block
    
    //check if the save was done properly
    if let realm = result.realm, let primaryKeys = result.value {
        let users: [User] = realm.getObjects(primaryKeys)
        print(users)
    } else {
    	 // manage the error
    }
})

```

### Helper methods to work with Realm

##### Get Primary Keys from an Array of Realm Objects

In order to make things easier when re-fetching the desired objects in the completion block, RealmStore offers a method to accumulate all the primary keys into an array and pass it to the completion block.

`public static func getPrimaryKeys<ClassType: Object, KeyType>(_ objects: Array<ClassType>) -> Array<KeyType>`

As primary keys are indexed, it's important to always fetch objects using them.

An example:

`let primaryKeys: [String] = RealmStore.getPrimaryKeys(objects)`

The expected workflow to use background thread is:

1. Perform the complex operation in the **background thread** write or read block.
2. Return an array of primary keys from the **background thread block**.
3. When the completion block is executed, use the returned primary keys (results parameter) to fetch again the realm objects in the **current thread (main thread)**.
4. Use your Realm objects :)

##### Get Objects from primary keys

The following method offers an easy way to fetch objects from a primary key array. It also offers the possibility to apply a predicate and sorting descriptors on the results.

```
public func getObjects<ClassType : Object,KeyType>( _ primaryKeys: Array<KeyType>, _ predicateFunction: ((ClassType) -> (Bool))?, _ sortingDescriptors: [T21SortingDescriptorSwift.SortDescriptor<ClassType>]?) -> Array<ClassType>
```

This method uses T21SortingDescriptorSwift.SortDescriptor class types. This kind of sorting is done in memory, after the objects has been fetched from the Realm. This is more expensive in terms of performance and memory, but it allows more complex sorting than the SortDescriptors offered by Realm framework.

An example:

```
let primaryKeys = ["A","B","C"]
let users: [User] = realm.getObjects(primaryKeys)
```

##### Get All Objects of an specific type

To perform a fetch for an specific object type you can use the following method.

```
public func getAllObjects<ClassType: Object>( _ predicate: NSPredicate?, _ sortingDescriptors: [RealmSwift.SortDescriptor]?) -> Array<ClassType>
```

This method uses the original RealmSwift.SortDescriptor to perform the sorting. This kind of sorting is faster but it only offers sorting by an object property.

An example:

```
let predicate = NSPredicate(format: "(name CONTAINS %@) OR (name CONTAINS %@)", "C", "D")
let objects: [User] = realm.getAllObjects(predicate)

```

##### Get or Create method

This is a useful method to perform an insertion/update operation. If the object related to an specific primary key does not exist, then it's created with the current primary key and added into the realm. If it exists, then it's returned. 

Very useful when performing update mappings for existing items in the DB.
