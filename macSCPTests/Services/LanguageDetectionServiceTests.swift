//
//  LanguageDetectionServiceTests.swift
//  macSCPTests
//
//  Unit tests for LanguageDetectionService
//

import XCTest
@testable import macSCP

@MainActor
final class LanguageDetectionServiceTests: XCTestCase {

    func testLanguage_SwiftFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "main.swift"), "swift")
    }

    func testLanguage_PythonFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "script.py"), "python")
    }

    func testLanguage_JavaScriptFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "app.js"), "javascript")
    }

    func testLanguage_TypeScriptFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "app.ts"), "typescript")
    }

    func testLanguage_TSXFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "component.tsx"), "typescript")
    }

    func testLanguage_JSXFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "component.jsx"), "typescript")
    }

    func testLanguage_YAMLFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "config.yaml"), "yaml")
    }

    func testLanguage_YMLFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "config.yml"), "yaml")
    }

    func testLanguage_JSONFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "data.json"), "json")
    }

    func testLanguage_XMLFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "pom.xml"), "xml")
    }

    func testLanguage_HTMLFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "index.html"), "xml")
    }

    func testLanguage_HTMFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "page.htm"), "xml")
    }

    func testLanguage_CSSFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "style.css"), "css")
    }

    func testLanguage_RubyFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "server.rb"), "ruby")
    }

    func testLanguage_GoFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "main.go"), "go")
    }

    func testLanguage_RustFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "lib.rs"), "rust")
    }

    func testLanguage_JavaFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "App.java"), "java")
    }

    func testLanguage_KotlinFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "Main.kt"), "kotlin")
    }

    func testLanguage_CFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "main.c"), "c")
    }

    func testLanguage_HFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "header.h"), "c")
    }

    func testLanguage_CPPFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "main.cpp"), "cpp")
    }

    func testLanguage_CCFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "main.cc"), "cpp")
    }

    func testLanguage_HPPFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "header.hpp"), "cpp")
    }

    func testLanguage_ObjectiveCFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "main.m"), "objectivec")
    }

    func testLanguage_CSharpFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "Program.cs"), "csharp")
    }

    func testLanguage_PhpFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "index.php"), "php")
    }

    func testLanguage_ShellFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "build.sh"), "bash")
    }

    func testLanguage_BashFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "script.bash"), "bash")
    }

    func testLanguage_ZshFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "config.zsh"), "bash")
    }

    func testLanguage_FishFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "config.fish"), "shell")
    }

    func testLanguage_SqlFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "query.sql"), "sql")
    }

    func testLanguage_TomlFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "config.toml"), "ini")
    }

    func testLanguage_MarkdownFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "README.md"), "markdown")
    }

    func testLanguage_SCSSFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "style.scss"), "scss")
    }

    func testLanguage_SASSFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "style.sass"), "scss")
    }

    func testLanguage_LessFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "style.less"), "scss")
    }

    func testLanguage_RFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "script.r"), "r")
    }

    func testLanguage_LuaFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "script.lua"), "lua")
    }

    func testLanguage_PerlFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "script.perl"), "perl")
    }

    func testLanguage_PlFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "script.pl"), "perl")
    }

    func testLanguage_DockerfileExtension() {
        XCTAssertEqual(LanguageDetectionService.language(for: "dev.dockerfile"), "dockerfile")
    }

    func testLanguage_IniFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "config.ini"), "ini")
    }

    func testLanguage_CfgFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "app.cfg"), "ini")
    }

    func testLanguage_ConfFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "app.conf"), "ini")
    }

    func testLanguage_PlistFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "Info.plist"), "xml")
    }

    func testLanguage_DiffFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "changes.diff"), "diff")
    }

    func testLanguage_PatchFile() {
        XCTAssertEqual(LanguageDetectionService.language(for: "fix.patch"), "diff")
    }

    func testLanguage_CaseInsensitive() {
        XCTAssertEqual(LanguageDetectionService.language(for: "MAIN.SWIFT"), "swift")
        XCTAssertEqual(LanguageDetectionService.language(for: "Script.PY"), "python")
        XCTAssertEqual(LanguageDetectionService.language(for: "APP.JS"), "javascript")
    }

    func testLanguage_UnknownExtension_ReturnsNil() {
        XCTAssertNil(LanguageDetectionService.language(for: "file.xyz"))
        XCTAssertNil(LanguageDetectionService.language(for: "file.unknown"))
    }

    func testLanguage_NoExtension_ReturnsNil() {
        XCTAssertNil(LanguageDetectionService.language(for: "Makefile"))
        XCTAssertNil(LanguageDetectionService.language(for: "README"))
    }

    func testLanguage_DockerfileFilename_ReturnsNil() {
        XCTAssertNil(LanguageDetectionService.language(for: "Dockerfile"))
    }
}
