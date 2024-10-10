//
//  File.swift
//  
//
//  Created by Mike Renoir on 13.02.2023.
//

import Foundation
import IOKit.ps

public class InternalBattery {
    public var name: String?

    public var timeToFull: Int?
    public var timeToEmpty: Int?

    public var manufacturer: String?
    public var manufactureDate: Date?

    public var currentCapacity: Int?
    public var maxCapacity: Int?
    public var designCapacity: Int?

    public var cycleCount: Int?
    public var designCycleCount: Int?

    public var acPowered: Bool?
    public var isCharging: Bool?
    public var isCharged: Bool?
    public var amperage: Int?
    public var voltage: Double?
    public var watts: Double?
    public var temperature: Double?

    public var charge: Double? {
        get {
            if let current = self.currentCapacity,
               let max = self.maxCapacity {
                return (Double(current) / Double(max)) * 100.0
            }

            return nil
        }
    }

    public var health: Double? {
        get {
            if let design = self.designCapacity,
               let current = self.maxCapacity {
                return (Double(current) / Double(design)) * 100.0
            }

            return nil
        }
    }

    public var timeLeft: String {
        get {
            if let isCharging = self.isCharging {
                if let minutes = isCharging ? self.timeToFull : self.timeToEmpty {
                    if minutes <= 0 {
                        return "-"
                    }

                    return String(format: "%.2d:%.2d", minutes / 60, minutes % 60)
                }
            }

            return "-"
        }
    }

    public var timeRemaining: Int? {
        get {
            if let isCharging = self.isCharging {
                return isCharging ? self.timeToFull : self.timeToEmpty
            }

            return nil
        }
    }
}
