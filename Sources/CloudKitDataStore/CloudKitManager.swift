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
    public static var identifier: String = "" {
        didSet {
            shared.container = CKContainer(identifier: CloudKitManager.identifier)
        }
    }
    
    internal var databaseType: DatabaseType = .publicDB
    
    private var container: CKContainer
    
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
    
    public func fetch(predicate: NSPredicate, numberOfResults: Int = 10, completion: @escaping (Swift.Result<([T], CKQueryOperation.Cursor?), Error>) -> Void) throws {
        let query = CKQuery(recordType: T.recordType, predicate: predicate)
        var objects: [T] = []
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = numberOfResults

        operation.recordFetchedBlock = { record in
            do {
                let object = try T(record: record)
                objects.append(object)
            } catch {
                completion(.failure(error))
            }
        }

        operation.queryCompletionBlock = { (cursor, error) in
            DispatchQueue.main.async {
                if error == nil {
                    completion(.success((objects, cursor)))
                } else if let error = error{
                    completion(.failure(error))
                }
            }
        }

        manager.currentDatabase.add(operation)

    }

    public func fetch(cursor: CKQueryOperation.Cursor, numberOfResults: Int = 10, completion: @escaping (Swift.Result<([T], CKQueryOperation.Cursor?), Error>) -> Void) throws {
        var objects: [T] = []
        let operation = CKQueryOperation(cursor: cursor)
        operation.resultsLimit = numberOfResults

        operation.recordFetchedBlock = { record in
            do {
                let object = try T(record: record)
                objects.append(object)
            } catch {
                completion(.failure(error))
            }
        }

        operation.queryCompletionBlock = { (cursor, error) in
            DispatchQueue.main.async {
                if error == nil {
                    completion(.success((objects, cursor)))
                } else if let error = error{
                    completion(.failure(error))
                }
            }
        }

        manager.currentDatabase.add(operation)

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
    
    public func update(recordID: CKRecord.ID, object: T, policy:  CKModifyRecordsOperation.RecordSavePolicy = .allKeys, completion: @escaping (Swift.Result<T, Error>) -> Void) throws{
        object.recordID = recordID
        let modifyOperation = CKModifyRecordsOperation(recordsToSave: [object.toRecord()], recordIDsToDelete: nil)
        modifyOperation.savePolicy = policy
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
