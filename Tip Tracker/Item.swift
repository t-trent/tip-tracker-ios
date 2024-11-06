//
//  Item.swift
//  Tip Tracker
//
//  Created by Trent Carlson on 2024-11-06.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
