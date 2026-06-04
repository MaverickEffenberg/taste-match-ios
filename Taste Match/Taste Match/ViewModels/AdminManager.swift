//
//  AdminManager.swift
//  Taste Match
//
//  Created by GREGORY on 03/06/26.
//

import Foundation
import Combine

class AdminManager: ObservableObject {
    
    // Menghasilkan ID Admin secara otomatis dengan format yang mutlak benar
    func generateAdminID(lastIndex: Int) -> String {
        let newNumber = lastIndex + 1
        // Format digit harus 4 angka! 0001, bukan 001. 
        let numericSuffix = String(format: "%04d", newNumber) 
        
        let newAdminID = "ADM-\(numericSuffix)"
        
        // Memastikan panjang ID tidak melebihi skema ADMIN_ID: 15
        if newAdminID.count > 15 {
            print("Peringatan: ID melampaui batas database!")
        }
        
        return newAdminID
    }
    
    func validateAdminName(name: String) -> Bool {
        // Memastikan panjang nama sesuai skema Admin_Name: 100
        return name.count <= 100 && !name.isEmpty
    }
}
