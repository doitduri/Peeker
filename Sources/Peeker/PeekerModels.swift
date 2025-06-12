//
//  PeekerModels.swift
//  Peeker
//
//  Created by duri on 6/3/25.
//

import Foundation

public struct PeekerMetrics {
    public let memory: MemoryInfo
    public let cpu: CPUInfo
    public let network: NetworkInfo
    public let timestamp: Date
    
    public struct MemoryInfo {
        public let used: Double // MB
        public let available: Double // MB
        public let pressure: MemoryPressure
        
        public enum MemoryPressure {
            case normal, warning, critical
        }
    }
    
    public struct CPUInfo {
        public let usage: Double // 0-100%
        public let temperature: Double? // Celsius (if available)
    }
    
    public struct NetworkInfo {
        public let isConnected: Bool
        public let connectionType: String
        public let downloadSpeed: Double // KB/s
        public let uploadSpeed: Double // KB/s
        public let signalStrength: NetworkSignalStrength?
        
        public enum NetworkSignalStrength: Int, CaseIterable {
            case poor = 1, fair = 2, good = 3, excellent = 4
            
            var emoji: String {
                switch self {
                case .poor: return "📶"
                case .fair: return "📶📶"
                case .good: return "📶📶📶"
                case .excellent: return "📶📶📶📶"
                }
            }
        }
    }
}
