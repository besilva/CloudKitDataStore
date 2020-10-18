//
//  CloudKitManager.swift
//  TestCloudkit
//
//  Created by Bernardo Silva on 13/10/20.
//  Copyright © 2020 Bernardo Silva. All rights reserved.
//

import CloudKit
import Foundation

/// Represents the nature of the CloudKitDataBase
public enum DatabaseType {
    case privateDB
    case publicDB
    case sharedDB
}

/// Describes the Errors that may occur on operations in CloudKitManager
public enum CloudKitError: Error {
    case invalidRecordID
    case unableToConvertRecord
}

public class CloudKitManager: NSObject {
    
    // MARK: - Properties

    internal static let shared = CloudKitManager()
    public static var identifier: String = ""
    
    internal var databaseType: DatabaseType = .publicDB
    
    private let container: CKContainer
    
    internal var currentDatabase: CKDatabase {
        switch self.databaseType {
        case .privateDB:
            return container.privateCloudDatabase
        case .publicDB:
            return container.publicCloudDatabase
        case .sharedDB:
            return container.sharedCloudDatabase
        }
    }
    
    private override init() {
        if !CloudKitManager.identifier.isEmpty {
            container =  CKContainer(identifier: CloudKitManager.identifier)
        } else {
            container = CKContainer.default()
        }
        
    }
    
    public func changeDatabase(type: DatabaseType) {
        databaseType = type
    }
    
}

public class DAO<T> where T: CloudObject {
    let manager: CloudKitManager = CloudKitManager.shared
    
    public init() {}
    
    public func fetch(predicate: NSPredicate, completion: @escaping (Swift.Result<[T], Error>) -> Void) throws {
        let query = CKQuery(recordType: T.recordType, predicate: predicate)
        
        
        manager.currentDatabase.perform(
            query,
            inZoneWith: CKRecordZone.default().zoneID
        ) { results, error in
            if let error = error {
                completion(.failure(error))
            }
            guard let results = results else { return }
            var contents: [T] = []
            for result in results {
                do {
                    let content = try T(record: result)
                    contents.append(content)
                } catch {
                    return completion(.failure(CloudKitError.unableToConvertRecord))
                }
            }
            
            completion(.success(contents))
        }
    }
    
    public func fetchOne(recordID: CKRecord.ID, completion: @escaping (Result<T, Error>) -> Void) throws{
         manager.currentDatabase.fetch(withRecordID: recordID) { record, error in
            guard let record = record else {
                if let error = error {
                    return completion(.failure(error))
                }
                return
            }
            do {
                completion(.success( try T(record: record)))
            } catch {
                completion(.failure(CloudKitError.unableToConvertRecord))
            }
        }
    }
    
    public func delete(object: T, completion: @escaping (Swift.Result<CKRecord.ID?, Error>) -> Void) {
        guard let ID = object.recordID else {
            return completion(.failure(CloudKitError.invalidRecordID))
        }
        manager.currentDatabase.delete(withRecordID: ID) { (id, error) in
            completion(.success(id))
        }
    }
    
    
    public func save(object: T, completion: @escaping (Swift.Result<T, Error>) -> Void) throws{
        let record = object.toRecord()
        manager.currentDatabase.save(record) { (savedRecord, error) in
            guard let savedRecord = savedRecord else {
                if let error = error {
                    return completion(.failure(error))
                }
                return
            }
            do {
                let savedObject = try T(record: savedRecord)
                completion(.success(savedObject))
            } catch {
                completion(.failure(CloudKitError.unableToConvertRecord))
            }
        }
    }
    
    public func update(recordID: CKRecord.ID, object: T, completion: @escaping (Swift.Result<T, Error>) -> Void) throws{
        object.recordID = recordID
        let modifyOperation = CKModifyRecordsOperation(recordsToSave: [object.toRecord()], recordIDsToDelete: nil)
        modifyOperation.savePolicy = .allKeys
        modifyOperation.qualityOfService = QualityOfService.userInitiated
        modifyOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in
            //   the completion block code here
            guard let savedRecords = savedRecords,
                operationError == nil else {
                if let error = operationError{
                    return completion(.failure(error))
                }
                return
            }
            do {
                let object = try T(record: savedRecords[0])
                completion(.success(object))
            } catch {
                completion(.failure(CloudKitError.unableToConvertRecord))
            }
           

        }
        manager.currentDatabase.add(modifyOperation)
    }
}
