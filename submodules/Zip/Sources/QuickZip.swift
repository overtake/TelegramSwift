//
//  QuickZip.swift
//  Zip
//
//  Created by Roy Marmelstein on 16/01/2016.
//  Copyright © 2016 Roy Marmelstein. All rights reserved.
//

import Foundation

extension Zip {
    
    /**
     Get search path directory. For tvOS Documents directory doesn't exist.
     
     - returns: Search path directory
     */
    fileprivate class func searchPathDirectory() -> FileManager.SearchPathDirectory {
        var searchPathDirectory: FileManager.SearchPathDirectory = .documentDirectory
        
        #if os(tvOS)
            searchPathDirectory = .cachesDirectory
        #endif
        
        return searchPathDirectory
    }
    
    //MARK: Quick Unzip
    
    /**
     Quick unzip a file. Unzips to a new folder inside the app's documents folder with the zip file's name.
     
     - parameter path: Path of zipped file. NSURL.
     
     - throws: Error if unzipping fails or if file is not found. Can be printed with a description variable.
     
     - returns: NSURL of the destination folder.
     */
    public class func quickUnzipFile(_ path: URL) throws -> URL {
        return try quickUnzipFile(path, progress: nil)
    }
    
    /**
     Quick unzip a file. Unzips to a new folder inside the app's documents folder with the zip file's name.
     
     - parameter path: Path of zipped file. NSURL.
     - parameter progress: A progress closure called after unzipping each file in the archive. Double value betweem 0 and 1.
     
     - throws: Error if unzipping fails or if file is not found. Can be printed with a description variable.
     
     - notes: Supports implicit progress composition
     
     - returns: NSURL of the destination folder.
     */
    public class func quickUnzipFile(_ path: URL, progress: ((_ progress: Double) -> ())?) throws -> URL {
        let fileManager = FileManager.default

        let fileExtension = path.pathExtension
        let fileName = path.lastPathComponent

        let directoryName = fileName.replacingOccurrences(of: ".\(fileExtension)", with: "")
        let documentsUrl = fileManager.urls(for: self.searchPathDirectory(), in: .userDomainMask)[0] as URL
        do {
            let destinationUrl = documentsUrl.appendingPathComponent(directoryName, isDirectory: true)
            try self.unzipFile(path, destination: destinationUrl, overwrite: true, password: nil, progress: progress)
            return destinationUrl
        }catch{
            throw(ZipError.unzipFail)
        }
    }
    
    //MARK: Quick Zip
    
    /**
     Quick zip files.
     
     - parameter paths: Array of NSURL filepaths.
     - parameter fileName: File name for the resulting zip file.
     
     - throws: Error if zipping fails.
     
     - notes: Supports implicit progress composition
     
     - returns: NSURL of the destination folder.
     */
    public class func quickZipFiles(_ paths: [URL], fileName: String) throws -> URL {
        return try quickZipFiles(paths, fileName: fileName, progress: nil)
    }
    
    /**
     Quick zip files.
     
     - parameter paths: Array of NSURL filepaths.
     - parameter fileName: File name for the resulting zip file.
     - parameter progress: A progress closure called after unzipping each file in the archive. Double value betweem 0 and 1.
     
     - throws: Error if zipping fails.
     
     - notes: Supports implicit progress composition
     
     - returns: NSURL of the destination folder.
     */
    public class func quickZipFiles(_ paths: [URL], fileName: String, progress: ((_ progress: Double) -> ())?) throws -> URL {
        let fileManager = FileManager.default
        let documentsUrl = fileManager.urls(for: self.searchPathDirectory(), in: .userDomainMask)[0] as URL
        let destinationUrl = documentsUrl.appendingPathComponent("\(fileName).zip")
        try self.zipFiles(paths: paths, zipFilePath: destinationUrl, password: nil, progress: progress)
        return destinationUrl
    }
    
    
}
