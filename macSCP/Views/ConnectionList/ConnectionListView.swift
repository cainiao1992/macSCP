//
//  ConnectionListView.swift
//  macSCP
//
//  Main window showing folders and connections
//

import SwiftData
import SwiftUI
import os

struct ConnectionListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var folders: [ConnectionFolder]
    @Query private var allConnections: [SSHConnection]

    @State private var viewModel: ConnectionListViewModel?
    @State private var selection: SidebarSelection? = .all
    @State private var showingNewFolderSheet = false
    @State private var folderToDelete: ConnectionFolder?
    @State private var newFolderName = ""

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .sheet(isPresented: $showingNewFolderSheet) {
            NewFolderView(folderName: $newFolderName, onCreate: createFolder)
        }
        .deleteFolderAlert(
            folder: $folderToDelete,
            onKeepConnections: deleteFolderOnly,
            onDeleteAll: deleteFolderAndConnections
        )
        .onAppear {
            if viewModel == nil {
                viewModel = ConnectionListViewModel(modelContext: modelContext)
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        List(selection: $selection) {
            AllConnectionsRow(count: allConnections.count)

            Section("Folders") {
                ForEach(folders) { folder in
                    FolderRowView(folder: folder) {
                        folderToDelete = folder
                    }
                }

                Button(action: { showingNewFolderSheet = true }) {
                    Label("New Folder", systemImage: "plus.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle(AppConstants.appName)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .all:
            AllConnectionsView(allConnections: allConnections)
        case .folder(let folder):
            FolderContentView(folder: folder)
        case .none:
            NoFolderSelectedView(onCreateFolder: {
                showingNewFolderSheet = true
            })
        }
    }

    // MARK: - Folder Operations

    private func createFolder() {
        guard let folder = viewModel?.createFolder(name: newFolderName) else { return }
        newFolderName = ""
        showingNewFolderSheet = false
        selection = .folder(folder)
    }

    private func clearSelectionIfNeeded(for folder: ConnectionFolder) {
        if case .folder(let selectedFolder) = selection,
            selectedFolder.id == folder.id
        {
            selection = .all
        }
        folderToDelete = nil
    }

    private func deleteFolderOnly(_ folder: ConnectionFolder) {
        withAnimation {
            viewModel?.deleteFolderOnly(folder)
            clearSelectionIfNeeded(for: folder)
        }
    }

    private func deleteFolderAndConnections(_ folder: ConnectionFolder) {
        withAnimation {
            viewModel?.deleteFolderAndConnections(folder)
            clearSelectionIfNeeded(for: folder)
        }
    }
}

#Preview {
    ConnectionListView()
        .modelContainer(
            for: [ConnectionFolder.self, SSHConnection.self],
            inMemory: true
        )
}
