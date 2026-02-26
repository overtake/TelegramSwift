//
//  ZipUtilities.swift
//  Zip
//
//  Created by Roy Marmelstein on 26/01/2016.
//  Copyright © 2016 Roy Marmelstein. All rights reserved.
//

import Foundation

internal class ZipUtilities {
    
    /*
     Include root directory.
     Default is true.
     
     e.g. The Test directory contains two files A.txt and B.txt.
     
     As true:
     $ zip -r Test.zip Test/
     $ unzip -l Test.zip
        Test/
        Test/A.txt
        Test/B.txt
     
     As false:
     $ zip -r Test.zip Test/
     $ unzip -l Test.zip
        A.txt
        B.txt
    */
    let includeRootDirectory = true

    // File manager
    let fileManager = FileManager.default

    /**
     *  ProcessedFilePath struct
     */
    internal struct ProcessedFilePath {
        let filePathURL: URL
        let fileName: String?
        
        func filePath() -> String {
            return filePathURL.path
        }
    }
    
    //MARK: Path processing
    
    /**
    Process zip paths
    
    - parameter paths: Paths as NSURL.
    
    - returns: Array of ProcessedFilePath structs.
    */
    internal func processZipPaths(_ paths: [URL]) -> [ProcessedFilePath]{
        var processedFilePaths = [ProcessedFilePath]()
        for path in paths {
            let filePath = path.path
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
            if !isDirectory.boolValue {
                let processedPath = ProcessedFilePath(filePathURL: path, fileName: path.lastPathComponent)
                processedFilePaths.append(processedPath)
            }
            else {
                let directoryContents = expandDirectoryFilePath(path)
                processedFilePaths.append(contentsOf: directoryContents)
            }
        }
        return processedFilePaths
    }
    
    
    /**
     Expand directory contents and parse them into ProcessedFilePath structs.
     
     - parameter directory: Path of folder as NSURL.
     
     - returns: Array of ProcessedFilePath structs.
     */
    internal func expandDirectoryFilePath(_ directory: URL) -> [ProcessedFilePath] {
        var processedFilePaths = [ProcessedFilePath]()
        let directoryPath = directory.path
        if let enumerator = fileManager.enumerator(atPath: directoryPath) {
            while let filePathComponent = enumerator.nextObject() as? String {
                let path = directory.appendingPathComponent(filePathComponent)
                let filePath = path.path

                var isDirectory: ObjCBool = false
                fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
                if !isDirectory.boolValue {
                    var fileName = filePathComponent
                    if includeRootDirectory {
                        let directoryName = directory.lastPathComponent
                        fileName = (directoryName as NSString).appendingPathComponent(filePathComponent)
                    }
                    let processedPath = ProcessedFilePath(filePathURL: path, fileName: fileName)
                    processedFilePaths.append(processedPath)
                }
            }
        }
        return processedFilePaths
    }

}
