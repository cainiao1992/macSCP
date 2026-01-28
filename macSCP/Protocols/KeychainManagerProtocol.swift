//
//  KeychainManagerProtocol.swift
//  macSCP
//
//  Created by Nevil Macwan on 29/01/26.
//

import Foundation

protocol KeychainManagerProtocol {
    func savePassword(_ password: String, for connectionId: String) -> Bool
    func getPassword(for connectionId: String) -> String?
    func deletePassword(for connectionId: String) -> Bool
    func updatePassword(_ password: String, for connectionId: String) -> Bool
}
