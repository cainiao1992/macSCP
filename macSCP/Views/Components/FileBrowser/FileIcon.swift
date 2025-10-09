//
//  FileIcon.swift
//  macSCP
//
//  File icon component with type-based icons and colors
//

import SwiftUI

struct FileIcon: View {
    let file: RemoteFile
    var size: CGFloat = 20

    var iconName: String {
        if file.isDirectory {
            return "folder.fill"
        }

        let ext = (file.name as NSString).pathExtension.lowercased()
        switch ext {
        case "txt", "md", "log":
            return "doc.text.fill"
        case "jpg", "jpeg", "png", "gif", "bmp", "svg":
            return "photo.fill"
        case "mp4", "mov", "avi", "mkv":
            return "video.fill"
        case "mp3", "wav", "aac", "flac":
            return "music.note"
        case "zip", "tar", "gz", "rar", "7z":
            return "doc.zipper"
        case "pdf":
            return "doc.fill"
        case "sh", "bash", "zsh":
            return "terminal.fill"
        case "py", "js", "java", "swift", "cpp", "c", "h":
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "doc.fill"
        }
    }

    var iconColor: Color {
        if file.isDirectory {
            return .blue
        }

        let ext = (file.name as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "bmp", "svg":
            return .orange
        case "mp4", "mov", "avi", "mkv":
            return .purple
        case "mp3", "wav", "aac", "flac":
            return .pink
        case "zip", "tar", "gz", "rar", "7z":
            return .gray
        case "pdf":
            return .red
        case "sh", "bash", "zsh":
            return .green
        case "py", "js", "java", "swift", "cpp", "c", "h":
            return .blue
        default:
            return .gray
        }
    }

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: size * 0.55, weight: .medium))
            .foregroundColor(iconColor)
            .symbolRenderingMode(.hierarchical)
            .frame(width: size, height: size)
    }
}
