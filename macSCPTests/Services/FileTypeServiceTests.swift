//
//  FileTypeServiceTests.swift
//  macSCPTests
//
//  Unit tests for FileTypeService
//

import XCTest
@testable import macSCP

@MainActor
final class FileTypeServiceTests: XCTestCase {

    // MARK: - iconName Tests

    func testIconName_SwiftFile() {
        let file = RemoteFile(name: "main.swift", path: "/main.swift", isDirectory: false, size: 1024, permissions: "-rw-r--r--")
        XCTAssertEqual(FileTypeService.iconName(for: file), "chevron.left.forwardslash.chevron.right")
    }

    func testIconName_Directory() {
        let dir = RemoteFile(name: "folder", path: "/folder", isDirectory: true, size: 0, permissions: "drwxr-xr-x")
        XCTAssertEqual(FileTypeService.iconName(for: dir), "folder.fill")
    }

    func testIconName_ImageFile() {
        let file = RemoteFile(name: "photo.jpg", path: "/photo.jpg", isDirectory: false, size: 2048, permissions: "-rw-r--r--")
        XCTAssertEqual(FileTypeService.iconName(for: file), "photo.fill")
    }

    func testIconName_PdfFile() {
        let file = RemoteFile(name: "doc.pdf", path: "/doc.pdf", isDirectory: false, size: 4096, permissions: "-rw-r--r--")
        XCTAssertEqual(FileTypeService.iconName(for: file), "doc.richtext.fill")
    }

    func testIconName_ArchiveFile() {
        let file = RemoteFile(name: "archive.zip", path: "/archive.zip", isDirectory: false, size: 8192, permissions: "-rw-r--r--")
        XCTAssertEqual(FileTypeService.iconName(for: file), "doc.zipper")
    }

    func testIconName_TextFile() {
        let file = RemoteFile(name: "readme.txt", path: "/readme.txt", isDirectory: false, size: 512, permissions: "-rw-r--r--")
        XCTAssertEqual(FileTypeService.iconName(for: file), "doc.text.fill")
    }

    func testIconName_ConfigurationFile() {
        let file = RemoteFile(name: "config.json", path: "/config.json", isDirectory: false, size: 256, permissions: "-rw-r--r--")
        XCTAssertEqual(FileTypeService.iconName(for: file), "gearshape.fill")
    }

    func testIconName_UnknownFile() {
        let file = RemoteFile(name: "data.xyz", path: "/data.xyz", isDirectory: false, size: 128, permissions: "-rw-r--r--")
        XCTAssertEqual(FileTypeService.iconName(for: file), "doc.fill")
    }

    // MARK: - iconColor Tests

    func testIconColor_CodeFile() {
        let file = RemoteFile(name: "main.swift", path: "/main.swift", isDirectory: false, size: 1024, permissions: "-rw-r--r--")
        let color = FileTypeService.iconColor(for: file)
        XCTAssertNotNil(color)
    }

    func testIconColor_Directory() {
        let dir = RemoteFile(name: "folder", path: "/folder", isDirectory: true, size: 0, permissions: "drwxr-xr-x")
        let color = FileTypeService.iconColor(for: dir)
        XCTAssertNotNil(color)
    }

    func testIconColor_ImageFile() {
        let file = RemoteFile(name: "photo.jpg", path: "/photo.jpg", isDirectory: false, size: 2048, permissions: "-rw-r--r--")
        let color = FileTypeService.iconColor(for: file)
        XCTAssertNotNil(color)
    }

    // MARK: - isPreviewable Tests

    func testIsPreviewable_CodeFile() {
        let file = RemoteFile(name: "main.swift", path: "/main.swift", isDirectory: false, size: 1024, permissions: "-rw-r--r--")
        XCTAssertTrue(FileTypeService.isPreviewable(file))
    }

    func testIsPreviewable_TextFile() {
        let file = RemoteFile(name: "README.txt", path: "/README.txt", isDirectory: false, size: 512, permissions: "-rw-r--r--")
        XCTAssertTrue(FileTypeService.isPreviewable(file))
    }

    func testIsPreviewable_ConfigurationFile() {
        let file = RemoteFile(name: "config.json", path: "/config.json", isDirectory: false, size: 256, permissions: "-rw-r--r--")
        XCTAssertTrue(FileTypeService.isPreviewable(file))
    }

    func testIsPreviewable_ImageFileNotPreviewable() {
        let file = RemoteFile(name: "photo.jpg", path: "/photo.jpg", isDirectory: false, size: 2048, permissions: "-rw-r--r--")
        XCTAssertFalse(FileTypeService.isPreviewable(file))
    }

    func testIsPreviewable_DirectoryNotPreviewable() {
        let dir = RemoteFile(name: "folder", path: "/folder", isDirectory: true, size: 0, permissions: "drwxr-xr-x")
        XCTAssertFalse(FileTypeService.isPreviewable(dir))
    }

    func testIsPreviewable_LargeFileNotPreviewable() {
        let file = RemoteFile(name: "large.swift", path: "/large.swift", isDirectory: false, size: 20 * 1024 * 1024, permissions: "-rw-r--r--")
        XCTAssertFalse(FileTypeService.isPreviewable(file))
    }

    // MARK: - typeDescription Tests

    func testTypeDescription_SwiftFile() {
        let file = RemoteFile(name: "main.swift", path: "/main.swift", isDirectory: false, size: 1024, permissions: "-rw-r--r--")
        XCTAssertEqual(FileTypeService.typeDescription(for: file), "Swift Source")
    }

    func testTypeDescription_PythonFile() {
        let file = RemoteFile(name: "script.py", path: "/script.py", isDirectory: false, size: 512, permissions: "-rw-r--r--")
        XCTAssertEqual(FileTypeService.typeDescription(for: file), "Python Script")
    }

    func testTypeDescription_Directory() {
        let dir = RemoteFile(name: "folder", path: "/folder", isDirectory: true, size: 0, permissions: "drwxr-xr-x")
        XCTAssertEqual(FileTypeService.typeDescription(for: dir), "Folder")
    }

    func testTypeDescription_UnknownExtension() {
        let file = RemoteFile(name: "file.xyz", path: "/file.xyz", isDirectory: false, size: 256, permissions: "-rw-r--r--")
        let desc = FileTypeService.typeDescription(for: file)
        XCTAssertFalse(desc.isEmpty)
    }

    // MARK: - formatSize Tests

    func testFormatSize_Bytes() {
        let expected = ByteCountFormatter.string(fromByteCount: 512, countStyle: .file)
        XCTAssertEqual(FileTypeService.formatSize(512), expected)
    }

    func testFormatSize_Kilobytes() {
        let expected = ByteCountFormatter.string(fromByteCount: 1536, countStyle: .file)
        XCTAssertEqual(FileTypeService.formatSize(1536), expected)
    }

    func testFormatSize_Megabytes() {
        let expected = ByteCountFormatter.string(fromByteCount: 1572864, countStyle: .file)
        XCTAssertEqual(FileTypeService.formatSize(1572864), expected)
    }

    func testFormatSize_Gigabytes() {
        let expected = ByteCountFormatter.string(fromByteCount: 1610612736, countStyle: .file)
        XCTAssertEqual(FileTypeService.formatSize(1610612736), expected)
    }

    func testFormatSize_Zero() {
        let expected = ByteCountFormatter.string(fromByteCount: 0, countStyle: .file)
        XCTAssertEqual(FileTypeService.formatSize(0), expected)
    }

    // MARK: - formatPermissions Tests

    func testFormatPermissions_RegularFile() {
        let result = FileTypeService.formatPermissions("-rw-r--r--")
        XCTAssertTrue(result.contains("File"))
        XCTAssertTrue(result.contains("Read"))
        XCTAssertTrue(result.contains("Write"))
    }

    func testFormatPermissions_Directory() {
        let result = FileTypeService.formatPermissions("drwxr-xr-x")
        XCTAssertTrue(result.contains("Directory"))
    }

    func testFormatPermissions_ExecutableFile() {
        let result = FileTypeService.formatPermissions("-rwxr-xr-x")
        XCTAssertTrue(result.contains("File"))
        XCTAssertTrue(result.contains("Execute"))
    }

    func testFormatPermissions_SymbolicLink() {
        let result = FileTypeService.formatPermissions("lrwxr-xr-x")
        XCTAssertTrue(result.contains("Symbolic Link"))
    }

    func testFormatPermissions_ShortString_ReturnedAsIs() {
        let result = FileTypeService.formatPermissions("644")
        XCTAssertEqual(result, "644")
    }

    // MARK: - mimeType Tests

    func testMimeType_SwiftFile() {
        let file = RemoteFile(name: "main.swift", path: "/main.swift", isDirectory: false, size: 1024, permissions: "-rw-r--r--")
        let mime = FileTypeService.mimeType(for: file)
        XCTAssertFalse(mime.isEmpty)
    }

    func testMimeType_UnknownFile() {
        let file = RemoteFile(name: "file.xyz", path: "/file.xyz", isDirectory: false, size: 256, permissions: "-rw-r--r--")
        let mime = FileTypeService.mimeType(for: file)
        XCTAssertEqual(mime, "application/octet-stream")
    }
}
