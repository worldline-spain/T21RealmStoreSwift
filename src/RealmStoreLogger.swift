//
//  RealmStoreLogger.swift
//  RealmStore
//
//  Created by Eloi Guzmán Cerón on 08/08/2017.
//  Copyright © 2017 Worldline. All rights reserved.
//

import Foundation
import T21LoggerSwift

public class RealmStoreLogger {
    
    // MARK: Public methods
    public class func verbose(_ message: String?, _ file: String = #file, _ function: String = #function, line: Int = #line) {
        sharedInstance.verbose(message, file, function, line)
    }
    
    public class func debug(_ message: String?, _ file: String = #file, _ function: String = #function, line: Int = #line) {
        sharedInstance.debug(message, file, function, line)
    }
    
    public class func info(_ message: String?, _ file: String = #file, _ function: String = #function, line: Int = #line) {
        sharedInstance.info(message, file, function, line)
    }
    
    public class func warning(_ message: String?, _ file: String = #file, _ function: String = #function, line: Int = #line) {
        sharedInstance.warning(message, file, function, line)
    }
    
    public class func error(_ message: String?, _ file: String = #file, _ function: String = #function, line: Int = #line) {
        sharedInstance.error(message, file, function, line)
    }
    
    // MARK: Private methods
    private static let sharedInstance = T21LoggerSwift.T21Logger("RealmStore")
}
