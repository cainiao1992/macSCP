//
//  LanguageDetectionService.swift
//  macSCP
//
//  Maps file extensions to Highlightr (highlight.js) language identifiers
//

import Foundation

enum LanguageDetectionService {
    static func language(for fileName: String) -> String? {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "js": return "javascript"
        case "ts": return "typescript"
        case "html", "htm": return "xml"
        case "css": return "css"
        case "json": return "json"
        case "swift": return "swift"
        case "py": return "python"
        case "rb": return "ruby"
        case "go": return "go"
        case "rs": return "rust"
        case "java": return "java"
        case "kt": return "kotlin"
        case "c", "h": return "c"
        case "cpp", "cc", "hpp": return "cpp"
        case "m": return "objectivec"
        case "cs": return "csharp"
        case "php": return "php"
        case "sh", "bash": return "bash"
        case "zsh": return "bash"
        case "fish": return "shell"
        case "yaml", "yml": return "yaml"
        case "xml", "plist": return "xml"
        case "toml": return "ini"
        case "sql": return "sql"
        case "md", "markdown": return "markdown"
        case "jsx", "tsx": return "typescript"
        case "scss", "sass", "less": return "scss"
        case "r": return "r"
        case "lua": return "lua"
        case "perl", "pl": return "perl"
        case "dockerfile": return "dockerfile"
        case "ini", "cfg", "conf": return "ini"
        case "diff", "patch": return "diff"
        default: return nil
        }
    }
}
