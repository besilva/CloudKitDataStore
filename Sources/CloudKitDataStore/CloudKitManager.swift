//
//  CloudKitManager.swift
//
//
//  Created by Bernardo Silva on 13/10/20.
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
    case accessDenied
    case unknownError(Error?)
}

public class CloudKitManager: NSObject {
    
    // MARK: - Properties

    public static let shared = CloudKitManager()
    
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
    
    public func requestUserID(completion: @escaping (Swift.Result<CKRecord.ID, CloudKitError>) -> Void) {
        
        self.verifyStatus { (result) in
            
            switch result {
                
                case .success(let persmission) where persmission == .granted:
                    self.fetchUserID(completion: completion)
                
                case .success:
                    completion(.failure(.accessDenied))
                
                case .failure(let error):
                    completion(.failure(.unknownError(error)))
            }
        }
    }
    
    private func verifyStatus(completion: @escaping (Swift.Result<CKContainer_Application_PermissionStatus, Error>) -> Void) {
        
        self.container.status(forApplicationPermission: .userDiscoverability) { (permission, error) in
            
            if let error = error {
                completion(.failure(error))
                
            } else {
                completion(.success(permission))
            }
        }
    }
    
    private func fetchUserID(completion: @escaping (Swift.Result<CKRecord.ID, CloudKitError>) -> Void) {
        
        self.container.fetchUserRecordID { (id, error) in
            
            if let validID = id {
                completion(.success(validID))
            } else {
                completion(.failure(.unknownError(error)))
            }
        }
    }
}
