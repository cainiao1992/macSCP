//
//  RemoteFileTests.swift
//  macSCPTests
//
//  Unit tests for RemoteFile domain model and FileType enum
//

import XCTest
@testable import macSCP

@MainActor
final class RemoteFileTests: XCTestCase {

    // MARK: - RemoteFile Computed Properties

    func testIsFile_Directory() {
        let file = makeRemoteFile(isDirectory: true)
        XCTAssertFalse(file.isFile)
    }

    func testIsFile_RegularFile() {
        let file = makeRemoteFile(isDirectory: false)
        XCTAssertTrue(file.isFile)
    }

    func testDisplaySize_Directory() {
        let file = makeRemoteFile(isDirectory: true, size: 4096)
        XCTAssertEqual(file.displaySize, "--")
    }

    func testDisplaySize_RegularFile() {
        let file = makeRemoteFile(isDirectory: false, size: 1024)
        XCTAssertFalse(file.displaySize == "--")
        XCTAssertFalse(file.displaySize.isEmpty)
    }

    func testFileExtension_WithExtension() {
        let file = makeRemoteFile(name: "script.py")
        XCTAssertEqual(file.fileExtension, "py")
    }

    func testFileExtension_NoExtension() {
        let file = makeRemoteFile(name: "README")
        XCTAssertEqual(file.fileExtension, "")
    }

    func testFileExtension_MultipleDots() {
        let file = makeRemoteFile(name: "archive.tar.gz")
        XCTAssertEqual(file.fileExtension, "gz")
    }

    func testParentPath_NestedFile() {
        let file = makeRemoteFile(path: "/home/user/file.txt")
        XCTAssertEqual(file.parentPath, "/home/user")
    }

    func testIsHidden_Dotfile() {
        let file = makeRemoteFile(name: ".bashrc")
        XCTAssertTrue(file.isHidden)
    }

    func testIsHidden_RegularFile() {
        let file = makeRemoteFile(name: "file.txt")
        XCTAssertFalse(file.isHidden)
    }

    func testIsSymlink() {
        let file = makeRemoteFile(permissions: "lrwxr-xr-x")
        XCTAssertTrue(file.isSymlink)
    }

    func testIsSymlink_Directory() {
        let file = makeRemoteFile(permissions: "drwxr-xr-x")
        XCTAssertFalse(file.isSymlink)
    }

    func testIsExecutable() {
        let file = makeRemoteFile(permissions: "-rwxr-xr-x")
        XCTAssertTrue(file.isExecutable)
    }

    func testIsExecutable_NotExecutable() {
        let file = makeRemoteFile(permissions: "-rw-r--r--")
        XCTAssertFalse(file.isExecutable)
    }

    func testFileType_Directory() {
        let file = makeRemoteFile(isDirectory: true)
        XCTAssertEqual(file.fileType, .directory)
    }

    func testFileType_CodeFile() {
        let file = makeRemoteFile(name: "main.swift", isDirectory: false)
        XCTAssertEqual(file.fileType, .code)
    }

    // MARK: - FileType.from(extension:)

    // Text
    func testFileTypeFrom_Text() {
        let textExts = ["txt", "md", "markdown", "rtf", "log"]
        for ext in textExts {
            XCTAssertEqual(FileType.from(extension: ext), .text, "Extension '\(ext)' should be .text")
        }
    }

    // Code
    func testFileTypeFrom_Code() {
        let codeExts = [
            "swift", "js", "ts", "py", "rb", "go", "rs", "java",
            "kt", "c", "cpp", "h", "m", "cs", "php", "html",
            "css", "scss", "sql", "sh", "bash", "zsh"
        ]
        for ext in codeExts {
            XCTAssertEqual(FileType.from(extension: ext), .code, "Extension '\(ext)' should be .code")
        }
    }

    // Configuration
    func testFileTypeFrom_Configuration() {
        let configExts = ["json", "yaml", "yml", "xml", "plist", "ini", "conf", "toml", "env"]
        for ext in configExts {
            XCTAssertEqual(FileType.from(extension: ext), .configuration, "Extension '\(ext)' should be .configuration")
        }
    }

    // Image
    func testFileTypeFrom_Image() {
        let imageExts = ["jpg", "png", "gif", "svg", "webp", "heic"]
        for ext in imageExts {
            XCTAssertEqual(FileType.from(extension: ext), .image, "Extension '\(ext)' should be .image")
        }
    }

    // Video
    func testFileTypeFrom_Video() {
        let videoExts = ["mp4", "mov", "avi", "mkv"]
        for ext in videoExts {
            XCTAssertEqual(FileType.from(extension: ext), .video, "Extension '\(ext)' should be .video")
        }
    }

    // Audio
    func testFileTypeFrom_Audio() {
        let audioExts = ["mp3", "wav", "aac", "flac"]
        for ext in audioExts {
            XCTAssertEqual(FileType.from(extension: ext), .audio, "Extension '\(ext)' should be .audio")
        }
    }

    // Archive
    func testFileTypeFrom_Archive() {
        let archiveExts = ["zip", "tar", "gz", "7z", "rar"]
        for ext in archiveExts {
            XCTAssertEqual(FileType.from(extension: ext), .archive, "Extension '\(ext)' should be .archive")
        }
    }

    // Document
    func testFileTypeFrom_Document() {
        let docExts = ["doc", "docx", "odt"]
        for ext in docExts {
            XCTAssertEqual(FileType.from(extension: ext), .document, "Extension '\(ext)' should be .document")
        }
    }

    // Spreadsheet
    func testFileTypeFrom_Spreadsheet() {
        let sheetExts = ["xls", "xlsx", "csv", "ods"]
        for ext in sheetExts {
            XCTAssertEqual(FileType.from(extension: ext), .spreadsheet, "Extension '\(ext)' should be .spreadsheet")
        }
    }

    // Presentation
    func testFileTypeFrom_Presentation() {
        let presExts = ["ppt", "pptx", "key"]
        for ext in presExts {
            XCTAssertEqual(FileType.from(extension: ext), .presentation, "Extension '\(ext)' should be .presentation")
        }
    }

    // PDF
    func testFileTypeFrom_PDF() {
        XCTAssertEqual(FileType.from(extension: "pdf"), .pdf)
    }

    // Executable
    func testFileTypeFrom_Executable() {
        let exeExts = ["exe", "app", "dmg", "pkg"]
        for ext in exeExts {
            XCTAssertEqual(FileType.from(extension: ext), .executable, "Extension '\(ext)' should be .executable")
        }
    }

    // Unknown
    func testFileTypeFrom_Unknown() {
        XCTAssertEqual(FileType.from(extension: "xyz"), .unknown)
        XCTAssertEqual(FileType.from(extension: "abc123"), .unknown)
        XCTAssertEqual(FileType.from(extension: ""), .unknown)
    }

    // MARK: - FileType.iconName

    func testIconName_Directory() {
        XCTAssertEqual(FileType.directory.iconName, "folder.fill")
    }

    func testIconName_Text() {
        XCTAssertEqual(FileType.text.iconName, "doc.text.fill")
    }

    func testIconName_Code() {
        XCTAssertEqual(FileType.code.iconName, "chevron.left.forwardslash.chevron.right")
    }

    func testIconName_Image() {
        XCTAssertEqual(FileType.image.iconName, "photo.fill")
    }

    func testIconName_Video() {
        XCTAssertEqual(FileType.video.iconName, "video.fill")
    }

    func testIconName_Audio() {
        XCTAssertEqual(FileType.audio.iconName, "music.note")
    }

    func testIconName_Archive() {
        XCTAssertEqual(FileType.archive.iconName, "doc.zipper")
    }

    func testIconName_Document() {
        XCTAssertEqual(FileType.document.iconName, "doc.fill")
    }

    func testIconName_Spreadsheet() {
        XCTAssertEqual(FileType.spreadsheet.iconName, "tablecells.fill")
    }

    func testIconName_Presentation() {
        XCTAssertEqual(FileType.presentation.iconName, "play.rectangle.fill")
    }

    func testIconName_PDF() {
        XCTAssertEqual(FileType.pdf.iconName, "doc.richtext.fill")
    }

    func testIconName_Executable() {
        XCTAssertEqual(FileType.executable.iconName, "terminal.fill")
    }

    func testIconName_Configuration() {
        XCTAssertEqual(FileType.configuration.iconName, "gearshape.fill")
    }

    func testIconName_Unknown() {
        XCTAssertEqual(FileType.unknown.iconName, "doc.fill")
    }

    // MARK: - FileType.isEditable

    func testIsEditable_Text() {
        XCTAssertTrue(FileType.text.isEditable)
    }

    func testIsEditable_Code() {
        XCTAssertTrue(FileType.code.isEditable)
    }

    func testIsEditable_Configuration() {
        XCTAssertTrue(FileType.configuration.isEditable)
    }

    func testIsEditable_Image() {
        XCTAssertFalse(FileType.image.isEditable)
    }

    func testIsEditable_Video() {
        XCTAssertFalse(FileType.video.isEditable)
    }

    func testIsEditable_Audio() {
        XCTAssertFalse(FileType.audio.isEditable)
    }

    func testIsEditable_Directory() {
        XCTAssertFalse(FileType.directory.isEditable)
    }

    func testIsEditable_Unknown() {
        XCTAssertFalse(FileType.unknown.isEditable)
    }

    // MARK: - sortedFiles

    func testSortedFiles_DirectoriesFirst() {
        let files = [
            makeRemoteFile(name: "a.txt", isDirectory: false),
            makeRemoteFile(name: "folder", isDirectory: true),
            makeRemoteFile(name: "b.txt", isDirectory: false),
        ]
        let sorted = RemoteFile.sortedFiles(files, by: .name)
        XCTAssertTrue(sorted[0].isDirectory)
        XCTAssertTrue(sorted[1].isDirectory || sorted[1].isFile)
        XCTAssertTrue(sorted.last!.isFile)
    }

    func testSortedFiles_ByName_Ascending() {
        let files = [
            makeRemoteFile(name: "c.txt"),
            makeRemoteFile(name: "a.txt"),
            makeRemoteFile(name: "b.txt"),
        ]
        let sorted = RemoteFile.sortedFiles(files, by: .name, ascending: true)
        XCTAssertEqual(sorted.map(\.name), ["a.txt", "b.txt", "c.txt"])
    }

    func testSortedFiles_ByName_Descending() {
        let files = [
            makeRemoteFile(name: "a.txt"),
            makeRemoteFile(name: "c.txt"),
            makeRemoteFile(name: "b.txt"),
        ]
        let sorted = RemoteFile.sortedFiles(files, by: .name, ascending: false)
        XCTAssertEqual(sorted.map(\.name), ["c.txt", "b.txt", "a.txt"])
    }

    func testSortedFiles_BySize_Ascending() {
        let files = [
            makeRemoteFile(name: "big.txt", size: 3000),
            makeRemoteFile(name: "small.txt", size: 100),
            makeRemoteFile(name: "medium.txt", size: 500),
        ]
        let sorted = RemoteFile.sortedFiles(files, by: .size, ascending: true)
        XCTAssertEqual(sorted.map(\.size), [100, 500, 3000])
    }

    func testSortedFiles_ByDate_Ascending() {
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        let date3 = Date(timeIntervalSince1970: 3000)
        let files = [
            makeRemoteFile(name: "newest", modificationDate: date3),
            makeRemoteFile(name: "oldest", modificationDate: date1),
            makeRemoteFile(name: "middle", modificationDate: date2),
        ]
        let sorted = RemoteFile.sortedFiles(files, by: .date, ascending: true)
        XCTAssertEqual(sorted.map(\.name), ["oldest", "middle", "newest"])
    }

    func testSortedFiles_ByType_Ascending() {
        let files = [
            makeRemoteFile(name: "script.swift"),
            makeRemoteFile(name: "notes.txt"),
            makeRemoteFile(name: "data.json"),
        ]
        let sorted = RemoteFile.sortedFiles(files, by: .type, ascending: true)
        XCTAssertEqual(sorted.map(\.name), ["data.json", "script.swift", "notes.txt"])
    }

    func testSortedFiles_Empty() {
        let sorted = RemoteFile.sortedFiles([], by: .name)
        XCTAssertTrue(sorted.isEmpty)
    }

    func testSortedFiles_AllDirectories() {
        let files = [
            makeRemoteFile(name: "zebra", isDirectory: true),
            makeRemoteFile(name: "alpha", isDirectory: true),
        ]
        let sorted = RemoteFile.sortedFiles(files, by: .name)
        XCTAssertEqual(sorted.map(\.name), ["alpha", "zebra"])
    }

    func testSortedFiles_AllFiles() {
        let files = [
            makeRemoteFile(name: "z.txt"),
            makeRemoteFile(name: "a.txt"),
        ]
        let sorted = RemoteFile.sortedFiles(files, by: .name)
        XCTAssertEqual(sorted.map(\.name), ["a.txt", "z.txt"])
    }

    func testSortedFiles_NilModificationDate() {
        let date = Date(timeIntervalSince1970: 1000)
        let files = [
            makeRemoteFile(name: "with_date", modificationDate: date),
            makeRemoteFile(name: "no_date", modificationDate: nil),
        ]
        let sorted = RemoteFile.sortedFiles(files, by: .date, ascending: true)
        // nil uses .distantPast so it comes first
        XCTAssertEqual(sorted[0].name, "no_date")
        XCTAssertEqual(sorted[1].name, "with_date")
    }

    // MARK: - Helpers

    private func makeRemoteFile(
        name: String = "file.txt",
        path: String = "/home/user/file.txt",
        isDirectory: Bool = false,
        size: Int64 = 1024,
        permissions: String = "-rw-r--r--",
        modificationDate: Date? = Date()
    ) -> RemoteFile {
        RemoteFile(
            name: name, path: path, isDirectory: isDirectory,
            size: size, permissions: permissions,
            modificationDate: modificationDate
        )
    }
}
