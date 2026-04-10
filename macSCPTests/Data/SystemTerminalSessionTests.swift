//
//  SystemTerminalSessionTests.swift
//  macSCPTests
//
//  Unit tests for SystemTerminalSession security improvements
//

import XCTest
@testable import macSCP

final class SystemTerminalSessionTests: XCTestCase {

    // MARK: - Password Prompt Detection

    func testIsPasswordPrompt_StandardPassword() async {
        let session = SystemTerminalSession()
        let result = await session.isPasswordPrompt("user@host's password:")
        XCTAssertTrue(result)
    }

    func testIsPasswordPrompt_UppercasePassword() async {
        let session = SystemTerminalSession()
        let result = await session.isPasswordPrompt("Password:")
        XCTAssertTrue(result)
    }

    func testIsPasswordPrompt_LowercasePassword() async {
        let session = SystemTerminalSession()
        let result = await session.isPasswordPrompt("password:")
        XCTAssertTrue(result)
    }

    func testIsPasswordPrompt_Passphrase() async {
        let session = SystemTerminalSession()
        let result = await session.isPasswordPrompt("Enter passphrase for key '/home/user/.ssh/id_rsa':")
        XCTAssertTrue(result)
    }

    func testIsPasswordPrompt_PassPhraseWithSpace() async {
        let session = SystemTerminalSession()
        let result = await session.isPasswordPrompt("Enter pass phrase for key:")
        XCTAssertTrue(result)
    }

    func testIsPasswordPrompt_Passcode() async {
        let session = SystemTerminalSession()
        let result = await session.isPasswordPrompt("Verification passcode:")
        XCTAssertTrue(result)
    }

    func testIsPasswordPrompt_MixedCase() async {
        let session = SystemTerminalSession()
        let result = await session.isPasswordPrompt("Please enter your PASSWORD:")
        XCTAssertTrue(result)
    }

    func testIsPasswordPrompt_RegularOutput_False() async {
        let session = SystemTerminalSession()
        let result = await session.isPasswordPrompt("Last login: Fri Apr 10 12:00:00 2026")
        XCTAssertFalse(result)
    }

    func testIsPasswordPrompt_EmptyString_False() async {
        let session = SystemTerminalSession()
        let result = await session.isPasswordPrompt("")
        XCTAssertFalse(result)
    }

    func testIsPasswordPrompt_ShellPrompt_False() async {
        let session = SystemTerminalSession()
        let result = await session.isPasswordPrompt("user@server:~$ ")
        XCTAssertFalse(result)
    }

    // MARK: - C Array Helpers

    func testBuildCArray_CreatesNullTerminatedArray() async {
        let session = SystemTerminalSession()
        let args = ["hello", "world"]
        let array = await session.buildCArray(args)

        XCTAssertEqual(array.count, 3, "Should have 2 strings + nil terminator")
        XCTAssertNotNil(array[0])
        XCTAssertNotNil(array[1])
        XCTAssertNil(array[2], "Last element must be nil")

        let str0 = String(cString: array[0]!)
        let str1 = String(cString: array[1]!)
        XCTAssertEqual(str0, "hello")
        XCTAssertEqual(str1, "world")

        await session.freeCArray(array)
    }

    func testBuildCArray_EmptyArray() async {
        let session = SystemTerminalSession()
        let array = await session.buildCArray([])

        XCTAssertEqual(array.count, 1, "Should have nil terminator only")
        XCTAssertNil(array[0])

        await session.freeCArray(array)
    }

    func testFreeCArray_DoesNotCrash() async {
        let session = SystemTerminalSession()
        let array = await session.buildCArray(["a", "b", "c"])
        await session.freeCArray(array)
    }

    // MARK: - Environment Array

    func testBuildEnvCArray_IsNullTerminated() async {
        let session = SystemTerminalSession()
        let envp = await session.buildEnvCArray()

        guard let last = envp.last else {
            XCTFail("Array should have at least nil terminator")
            return
        }
        XCTAssertNil(last, "Last element must be nil")
        XCTAssertTrue(envp.count > 1, "Should contain at least one env var + nil")

        if let first = envp.first, let firstStr = first {
            let str = String(cString: firstStr)
            XCTAssertTrue(str.contains("="), "Each env entry must be KEY=VALUE format")
        }

        await session.freeCArray(envp)
    }

    func testBuildEnvCArray_ContainsKeyEnvVars() async {
        let session = SystemTerminalSession()
        let envp = await session.buildEnvCArray()

        var foundHome = false
        var foundPath = false
        for ptr in envp where ptr != nil {
            let str = String(cString: ptr!)
            if str.hasPrefix("HOME=") { foundHome = true }
            if str.hasPrefix("PATH=") { foundPath = true }
        }
        XCTAssertTrue(foundHome, "Must include HOME env var")
        XCTAssertTrue(foundPath, "Must include PATH env var")

        await session.freeCArray(envp)
    }

    // MARK: - Disconnect Clears Password State

    func testDisconnect_ClearsPasswordState() async {
        let session = SystemTerminalSession()
        await session.disconnect()
        let connected = await session.isConnected
        XCTAssertFalse(connected)
    }
}
