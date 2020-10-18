//
//  UIImage+CKAsset.swift
//  
//
//  Created by Lucas Antevere Santana on 18/10/20.
//

import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif


enum ImageFileType {
    
    case PNG
    case JPG(compressionQuality: CGFloat)
    
    var fileExtension: String {
        
        switch self {
            
            case .JPG:
                return ".jpg"
                
            case .PNG:
                return ".png"
        }
    }
}

enum ImageConversionError: Int, Error {
    case unableToConvertImageToData
    case unableToWriteDataToTemporaryFile
}

#if os(macOS)

extension NSImage {
    
    var pngData: Data? {
        
        if let tiff = self.tiffRepresentation, let tiffData = NSBitmapImageRep(data: tiff) {
            return tiffData.representation(using: .png, properties: [:])
        }
        
        return nil
    }
    
    func jpegData(compressionQuality: CGFloat) -> Data? {
        
        if let tiff = self.tiffRepresentation, let tiffData = NSBitmapImageRep(data: tiff) {
            return tiffData.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
        }
        
        return nil
    }
    
    func saveToTempLocation(withFileType fileType: ImageFileType) throws -> URL {
        
        let imageData: Data?
        
        switch fileType {
            
            case .JPG(let quality):
                imageData = self.jpegData(compressionQuality: quality)
                
            case .PNG:
                imageData = self.pngData
                
        }
        
        guard let data = imageData else {
            throw ImageConversionError.unableToConvertImageToData
        }
        
        let filename = ProcessInfo.processInfo.globallyUniqueString + fileType.fileExtension
        
        let url = NSURL.fileURL(withPath: NSTemporaryDirectory()).appendingPathComponent(filename)
        
        do {
            try data.write(to: url)
            
        } catch {
            throw ImageConversionError.unableToWriteDataToTemporaryFile
        }
        
        return url
    }
    
}

#else

extension UIImage {
    
    func saveToTempLocation(withFileType fileType: ImageFileType) throws -> URL {
        
        let imageData: Data?
        
        switch fileType {
            
            case .JPG(let quality):
                imageData = self.jpegData(compressionQuality: quality)
                
            case .PNG:
                imageData = self.pngData()
                
        }
        
        guard let data = imageData else {
            throw ImageConversionError.unableToConvertImageToData
        }
        
        let filename = ProcessInfo.processInfo.globallyUniqueString + fileType.fileExtension
        
        let url = NSURL.fileURL(withPath: NSTemporaryDirectory()).appendingPathComponent(filename)
        
        do {
            try data.write(to: url)
            
        } catch {
            throw ImageConversionError.unableToWriteDataToTemporaryFile
        }
        
        return url
    }
}

#endif
