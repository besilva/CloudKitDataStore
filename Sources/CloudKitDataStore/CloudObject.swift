//
//  File.swift
//  
//
//  Created by Lucas Antevere Santana on 18/10/20.
//

import CloudKit

/// Describes an Object as Convertable to an CKRecord
public protocol CloudObject: AnyObject {
    
    /// The id of the item
    var recordID: (CKRecord.ID)? { get set }
    
    /// The record type name created in CloudKit
    static var recordType: String { get }
    
    /// Initializes the object based on data from CKRecord
    /// - Parameter record: The Record containing the data
    init(record: CKRecord) throws
    
    /// Creates a CKRecord containing the same data that this object
    func toRecord() -> CKRecord
}
