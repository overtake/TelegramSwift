//
//  Zip.swift
//  Zip
//
//  Created by Roy Marmelstein on 13/12/2015.
//  Copyright © 2015 Roy Marmelstein. All rights reserved.
//

import Foundation
import Minizip

/// Zip error type
public enum ZipError: Error {
    /// File not found
    case fileNotFound
    /// Unzip fail
    case unzipFail
    /// Zip fail
    case zipFail
    case sizeLimit
    
    /// User readable description
    public var description: String {
        switch self {
        case .fileNotFound: return NSLocalizedString("File not found.", comment: "")
        case .unzipFail: return NSLocalizedString("Failed to unzip file.", comment: "")
        case .zipFail: return NSLocalizedString("Failed to zip file.", comment: "")
        case .sizeLimit: return NSLocalizedString("2.0 GB Limit.", comment: "")
        }
    }
}

public enum ZipCompression: Int {
    case NoCompression
    case BestSpeed
    case DefaultCompression
    case BestCompression

    internal var minizipCompression: Int32 {
        switch self {
        case .NoCompression:
            return Z_NO_COMPRESSION
        case .BestSpeed:
            return Z_BEST_SPEED
        case .DefaultCompression:
            return Z_DEFAULT_COMPRESSION
        case .BestCompression:
            return Z_BEST_COMPRESSION
        }
    }
}

/// Data in memory that will be archived as a file.
public struct ArchiveFile {
    var filename:String
    var data:NSData
    var modifiedTime:Date?

    public init(filename:String, data:NSData, modifiedTime:Date?) {
        self.filename = filename
        self.data = data
        self.modifiedTime = modifiedTime
    }
}



/// Zip class
public class Zip {
    
    /**
     Set of vaild file extensions
     */
    internal static var customFileExtensions: Set<String> = []
    
    // MARK: Lifecycle
    
    /**
     Init
     
     - returns: Zip object
     */
    public init () {
    }
    
    // MARK: Unzip
    
    /**
     Unzip file
     
     - parameter zipFilePath: Local file path of zipped file. NSURL.
     - parameter destination: Local file path to unzip to. NSURL.
     - parameter overwrite:   Overwrite bool.
     - parameter password:    Optional password if file is protected.
     - parameter progress: A progress closure called after unzipping each file in the archive. Double value betweem 0 and 1.
     
     - throws: Error if unzipping fails or if fail is not found. Can be printed with a description variable.
     
     - notes: Supports implicit progress composition
     */
    
    public class func unzipFile(_ zipFilePath: URL, destination: URL, overwrite: Bool, password: String?, progress: ((_ progress: Double) -> ())? = nil, fileOutputHandler: ((_ unzippedFile: URL) -> Void)? = nil) throws {
        
        // File manager
        let fileManager = FileManager.default
        
        // Check whether a zip file exists at path.
        let path = zipFilePath.path
        
        if fileManager.fileExists(atPath: path) == false || fileExtensionIsInvalid(zipFilePath.pathExtension) {
            throw ZipError.fileNotFound
        }
        
        // Unzip set up
        var ret: Int32 = 0
        var crc_ret: Int32 = 0
        let bufferSize: UInt32 = 4096
        var buffer = Array<CUnsignedChar>(repeating: 0, count: Int(bufferSize))
        
        // Progress handler set up
        var totalSize: Double = 0.0
        var currentPosition: Double = 0.0
        let fileAttributes = try fileManager.attributesOfItem(atPath: path)
        if let attributeFileSize = fileAttributes[FileAttributeKey.size] as? Double {
            totalSize += attributeFileSize
        }
        
        let progressTracker = Progress(totalUnitCount: Int64(totalSize))
        progressTracker.isCancellable = false
        progressTracker.isPausable = false
        progressTracker.kind = ProgressKind.file
        
        // Begin unzipping
        let zip = unzOpen64(path)
        defer {
            unzClose(zip)
        }
        if unzGoToFirstFile(zip) != UNZ_OK {
            throw ZipError.unzipFail
        }
        repeat {
            if let cPassword = password?.cString(using: String.Encoding.ascii) {
                ret = unzOpenCurrentFilePassword(zip, cPassword)
            }
            else {
                ret = unzOpenCurrentFile(zip);
            }
            if ret != UNZ_OK {
                throw ZipError.unzipFail
            }
            var fileInfo = unz_file_info64()
            memset(&fileInfo, 0, MemoryLayout<unz_file_info>.size)
            ret = unzGetCurrentFileInfo64(zip, &fileInfo, nil, 0, nil, 0, nil, 0)
            if ret != UNZ_OK {
                unzCloseCurrentFile(zip)
                throw ZipError.unzipFail
            }
            currentPosition += Double(fileInfo.compressed_size)
            let fileNameSize = Int(fileInfo.size_filename) + 1
            //let fileName = UnsafeMutablePointer<CChar>(allocatingCapacity: fileNameSize)
            let fileName = UnsafeMutablePointer<CChar>.allocate(capacity: fileNameSize)

            unzGetCurrentFileInfo64(zip, &fileInfo, fileName, UInt(fileNameSize), nil, 0, nil, 0)
            fileName[Int(fileInfo.size_filename)] = 0

            var pathString = String(cString: fileName)
            
            guard pathString.count > 0 else {
                throw ZipError.unzipFail
            }

            var isDirectory = false
            let fileInfoSizeFileName = Int(fileInfo.size_filename-1)
            if (fileName[fileInfoSizeFileName] == "/".cString(using: String.Encoding.utf8)?.first || fileName[fileInfoSizeFileName] == "\\".cString(using: String.Encoding.utf8)?.first) {
                isDirectory = true;
            }
            free(fileName)
            if pathString.rangeOfCharacter(from: CharacterSet(charactersIn: "/\\")) != nil {
                pathString = pathString.replacingOccurrences(of: "\\", with: "/")
            }

            let fullPath = destination.appendingPathComponent(pathString).path

            let creationDate = Date()

            let directoryAttributes = [FileAttributeKey.creationDate : creationDate,
                                       FileAttributeKey.modificationDate : creationDate]

            do {
                if isDirectory {
                    try fileManager.createDirectory(atPath: fullPath, withIntermediateDirectories: true, attributes: directoryAttributes)
                }
                else {
                    let parentDirectory = (fullPath as NSString).deletingLastPathComponent
                    try fileManager.createDirectory(atPath: parentDirectory, withIntermediateDirectories: true, attributes: directoryAttributes)
                }
            } catch {}
            if fileManager.fileExists(atPath: fullPath) && !isDirectory && !overwrite {
                unzCloseCurrentFile(zip)
                ret = unzGoToNextFile(zip)
            }

            var writeBytes: UInt64 = 0
            var filePointer: UnsafeMutablePointer<FILE>?
            filePointer = fopen(fullPath, "wb")
            while filePointer != nil {
                let readBytes = unzReadCurrentFile(zip, &buffer, bufferSize)
                if readBytes > 0 {
                    guard fwrite(buffer, Int(readBytes), 1, filePointer) == 1 else {
                        throw ZipError.unzipFail
                    }
                    writeBytes += UInt64(readBytes)
                }
                else {
                    break
                }
            }

            if let fp = filePointer { fclose(fp) }

            crc_ret = unzCloseCurrentFile(zip)
            if crc_ret == UNZ_CRCERROR {
                throw ZipError.unzipFail
            }
            guard writeBytes == fileInfo.uncompressed_size else {
                throw ZipError.unzipFail
            }

            //Set file permissions from current fileInfo
            if fileInfo.external_fa != 0 {
                let permissions = (fileInfo.external_fa >> 16) & 0x1FF
                //We will devifne a valid permission range between Owner read only to full access
                if permissions >= 0o400 && permissions <= 0o777 {
                    do {
                        try fileManager.setAttributes([.posixPermissions : permissions], ofItemAtPath: fullPath)
                    } catch {
                        print("Failed to set permissions to file \(fullPath), error: \(error)")
                    }
                }
            }

            ret = unzGoToNextFile(zip)
            
            // Update progress handler
            if let progressHandler = progress{
                progressHandler((currentPosition/totalSize))
            }
            
            if let fileHandler = fileOutputHandler,
                let encodedString = fullPath.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                let fileUrl = URL(string: encodedString) {
                fileHandler(fileUrl)
            }
            
            progressTracker.completedUnitCount = Int64(currentPosition)
            
        } while (ret == UNZ_OK && ret != UNZ_END_OF_LIST_OF_FILE)
        
        // Completed. Update progress handler.
        if let progressHandler = progress{
            progressHandler(1.0)
        }
        
        progressTracker.completedUnitCount = Int64(totalSize)
        
    }
    
    // MARK: Zip
    
    
    /**
     Zip files.
     
     - parameter paths:       Array of NSURL filepaths.
     - parameter zipFilePath: Destination NSURL, should lead to a .zip filepath.
     - parameter password:    Password string. Optional.
     - parameter compression: Compression strategy
     - parameter progress: A progress closure called after unzipping each file in the archive. Double value betweem 0 and 1.
     
     - throws: Error if zipping fails.
     
     - notes: Supports implicit progress composition
     */
    public class func zipFiles(paths: [URL], zipFilePath: URL, password: String?, compression: ZipCompression = .DefaultCompression, progress: ((_ progress: Double) -> ())?, cancel:@escaping()->Bool = { return false }) throws {
        
        

        
        // File manager
        let fileManager = FileManager.default
        
        // Check whether a zip file exists at path.
        let destinationPath = zipFilePath.path
        
        // Process zip paths
        let processedPaths = ZipUtilities().processZipPaths(paths)
        
        // Zip set up
        let chunkSize: Int = 16384
        
        // Progress handler set up
        var currentPosition: Double = 0.0
        var totalSize: Double = 0.0
        // Get totalSize for progress handler
        for path in processedPaths {
            if !cancel() {
                let filePath = path.filePath()
                let fileAttributes = try? fileManager.attributesOfItem(atPath: filePath)
                let fileSize = fileAttributes?[FileAttributeKey.size] as? Double
                if let fileSize = fileSize {
                    totalSize += fileSize
                }
                if totalSize > 1500 * 1024 * 1024 {
                    throw ZipError.sizeLimit
                }
            } else {
                return
            }
            
        }
        
        if let progressHandler = progress {
            progressHandler(0.0)
        }
        
        let progressTracker = Progress(totalUnitCount: Int64(totalSize))
        progressTracker.isCancellable = true
        progressTracker.isPausable = false
        progressTracker.kind = ProgressKind.file
        

        
        var cancelled: Bool = false
        // Begin Zipping
        let zip = zipOpen(destinationPath, APPEND_STATUS_CREATE)
        for path in processedPaths {
            if !cancel() {
                let filePath = path.filePath()
                var isDirectory: ObjCBool = false
                fileManager.fileExists(atPath: filePath, isDirectory: &isDirectory)
                if !isDirectory.boolValue {
                    let input = fopen(filePath, "r")
                    if input == nil {
                        throw ZipError.zipFail
                    }
                    let fileName = path.fileName
                    var zipInfo: zip_fileinfo = zip_fileinfo(tmz_date: tm_zip(tm_sec: 0, tm_min: 0, tm_hour: 0, tm_mday: 0, tm_mon: 0, tm_year: 0), dosDate: 0, internal_fa: 0, external_fa: 0)
                    do {
                        let fileAttributes = try fileManager.attributesOfItem(atPath: filePath)
                        if let fileDate = fileAttributes[FileAttributeKey.modificationDate] as? Date {
                            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fileDate)
                            zipInfo.tmz_date.tm_sec = UInt32(components.second!)
                            zipInfo.tmz_date.tm_min = UInt32(components.minute!)
                            zipInfo.tmz_date.tm_hour = UInt32(components.hour!)
                            zipInfo.tmz_date.tm_mday = UInt32(components.day!)
                            zipInfo.tmz_date.tm_mon = UInt32(components.month!) - 1
                            zipInfo.tmz_date.tm_year = UInt32(components.year!)
                        }
                        if let fileSize = fileAttributes[FileAttributeKey.size] as? Double {
                            currentPosition += fileSize
                        }
                    }
                    catch {}
                    let buffer = malloc(chunkSize)
                    if let password = password, let fileName = fileName {
                        zipOpenNewFileInZip3(zip, fileName, &zipInfo, nil, 0, nil, 0, nil,Z_DEFLATED, compression.minizipCompression, 0, -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY, password, 0)
                    }
                    else if let fileName = fileName {
                        zipOpenNewFileInZip3(zip, fileName, &zipInfo, nil, 0, nil, 0, nil,Z_DEFLATED, compression.minizipCompression, 0, -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY, nil, 0)
                    }
                    else {
                        throw ZipError.zipFail
                    }
                    var length: Int = 0
                    while (feof(input) == 0) {
                        length = fread(buffer, 1, chunkSize, input)
                        zipWriteInFileInZip(zip, buffer, UInt32(length))
                    }
                    
                    // Update progress handler
                    if let progressHandler = progress{
                        progressHandler((currentPosition/totalSize))
                    }
                    
                    progressTracker.completedUnitCount = Int64(currentPosition)
                    
                    zipCloseFileInZip(zip)
                    free(buffer)
                    fclose(input)
                }
            } else {
                cancelled = true
                progressTracker.cancel()
                break
            }
        }
        zipClose(zip, nil)
        // Completed. Update progress handler.
        if let progressHandler = progress{
            progressHandler(1.0)
        }
        
        if cancelled {
            try? FileManager.default.removeItem(atPath: destinationPath)
        }
        
        progressTracker.completedUnitCount = Int64(totalSize)
    }

    /**
     Zip data in memory.
     
     - parameter archiveFiles:Array of Archive Files.
     - parameter zipFilePath: Destination NSURL, should lead to a .zip filepath.
     - parameter password:    Password string. Optional.
     - parameter compression: Compression strategy
     - parameter progress: A progress closure called after unzipping each file in the archive. Double value betweem 0 and 1.
     
     - throws: Error if zipping fails.
     
     - notes: Supports implicit progress composition
     */
    public class func zipData(archiveFiles:[ArchiveFile], zipFilePath:URL, password: String?, compression: ZipCompression = .DefaultCompression, progress: ((_ progress: Double) -> ())?) throws {
        
        let destinationPath = zipFilePath.path

        // Progress handler set up
        var currentPosition: Int = 0
        var totalSize: Int = 0

        for archiveFile in archiveFiles {
            totalSize += archiveFile.data.length
        }

        let progressTracker = Progress(totalUnitCount: Int64(totalSize))
        progressTracker.isCancellable = false
        progressTracker.isPausable = false
        progressTracker.kind = ProgressKind.file

        // Begin Zipping
        let zip = zipOpen(destinationPath, APPEND_STATUS_CREATE)

        for archiveFile in archiveFiles {

            // Skip empty data
            if archiveFile.data.length == 0 {
                continue
            }

            // Setup the zip file info
            var zipInfo = zip_fileinfo(tmz_date: tm_zip(tm_sec: 0, tm_min: 0, tm_hour: 0, tm_mday: 0, tm_mon: 0, tm_year: 0),
                                       dosDate: 0,
                                       internal_fa: 0,
                                       external_fa: 0)

            if let modifiedTime = archiveFile.modifiedTime {
                let calendar = Calendar.current
                zipInfo.tmz_date.tm_sec = UInt32(calendar.component(.second, from: modifiedTime))
                zipInfo.tmz_date.tm_min = UInt32(calendar.component(.minute, from: modifiedTime))
                zipInfo.tmz_date.tm_hour = UInt32(calendar.component(.hour, from: modifiedTime))
                zipInfo.tmz_date.tm_mday = UInt32(calendar.component(.day, from: modifiedTime))
                zipInfo.tmz_date.tm_mon = UInt32(calendar.component(.month, from: modifiedTime))
                zipInfo.tmz_date.tm_year = UInt32(calendar.component(.year, from: modifiedTime))
            }

            // Write the data as a file to zip
            zipOpenNewFileInZip3(zip,
                                 archiveFile.filename,
                                 &zipInfo,
                                 nil,
                                 0,
                                 nil,
                                 0,
                                 nil,
                                 Z_DEFLATED,
                                 compression.minizipCompression,
                                 0,
                                 -MAX_WBITS,
                                 DEF_MEM_LEVEL,
                                 Z_DEFAULT_STRATEGY,
                                 password,
                                 0)
            zipWriteInFileInZip(zip, archiveFile.data.bytes, UInt32(archiveFile.data.length))
            zipCloseFileInZip(zip)

            // Update progress handler
            currentPosition += archiveFile.data.length

            if let progressHandler = progress{
                progressHandler((Double(currentPosition/totalSize)))
            }

            progressTracker.completedUnitCount = Int64(currentPosition)
        }

        zipClose(zip, nil)

        // Completed. Update progress handler.
        if let progressHandler = progress{
            progressHandler(1.0)
        }

        progressTracker.completedUnitCount = Int64(totalSize)
    }
    
    /**
     Check if file extension is invalid.
     
     - parameter fileExtension: A file extension.
     
     - returns: false if the extension is a valid file extension, otherwise true.
     */
    internal class func fileExtensionIsInvalid(_ fileExtension: String?) -> Bool {
        
        guard let fileExtension = fileExtension else { return true }
        
        return !isValidFileExtension(fileExtension)
    }
    
    /**
     Add a file extension to the set of custom file extensions
     
     - parameter fileExtension: A file extension.
     */
    public class func addCustomFileExtension(_ fileExtension: String) {
        customFileExtensions.insert(fileExtension)
    }
    
    /**
     Remove a file extension from the set of custom file extensions
     
     - parameter fileExtension: A file extension.
     */
    public class func removeCustomFileExtension(_ fileExtension: String) {
        customFileExtensions.remove(fileExtension)
    }
    
    /**
     Check if a specific file extension is valid
     
     - parameter fileExtension: A file extension.
     
     - returns: true if the extension valid, otherwise false.
     */
    public class func isValidFileExtension(_ fileExtension: String) -> Bool {
        
        let validFileExtensions: Set<String> = customFileExtensions.union(["zip", "cbz"])
        
        return validFileExtensions.contains(fileExtension)
    }
    
}
