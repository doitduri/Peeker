//
//  NetworkSpeedCalculator.swift
//  Peeker
//
//  Created by duri on 6/12/25.
//

import Foundation

class NetworkSpeedCalculator {
    private var previousData: NetworkData?
    private var lastUpdateTime: Date = Date()
    private var currentSpeeds: (download: Double, upload: Double) = (0, 0)
    private let updateQueue = DispatchQueue(label: "NetworkSpeedCalculator", qos: .utility)
    
    struct NetworkData {
        let bytesReceived: UInt64
        let bytesSent: UInt64
        let timestamp: Date
    }
    
    func startMonitoring() {
        updateNetworkSpeeds()
    }
    
    func getCurrentSpeeds() -> (download: Double, upload: Double) {
        updateQueue.sync {
            updateNetworkSpeeds()
            return currentSpeeds
        }
    }
    
    private func updateNetworkSpeeds() {
        let currentData = getNetworkData()
        let currentTime = Date()
        
        defer {
            previousData = NetworkData(
                bytesReceived: currentData.bytesReceived,
                bytesSent: currentData.bytesSent,
                timestamp: currentTime
            )
            lastUpdateTime = currentTime
        }
        
        guard let previous = previousData else { return }
        
        let timeDiff = currentTime.timeIntervalSince(previous.timestamp)
        guard timeDiff > 0.5 else { return } // 최소 0.5초 간격
        
        let downloadDiff = currentData.bytesReceived > previous.bytesReceived ?
            currentData.bytesReceived - previous.bytesReceived : 0
        let uploadDiff = currentData.bytesSent > previous.bytesSent ?
            currentData.bytesSent - previous.bytesSent : 0
        
        currentSpeeds.download = Double(downloadDiff) / timeDiff / 1024.0 // KB/s
        currentSpeeds.upload = Double(uploadDiff) / timeDiff / 1024.0 // KB/s
    }
    
    private func getNetworkData() -> NetworkData {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        var bytesReceived: UInt64 = 0
        var bytesSent: UInt64 = 0
        
        guard getifaddrs(&ifaddr) == 0 else {
            return NetworkData(bytesReceived: 0, bytesSent: 0, timestamp: Date())
        }
        
        defer { freeifaddrs(ifaddr) }
        
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            
            guard let interface = ptr?.pointee else { continue }
            let name = String(cString: interface.ifa_name)
            
            if name.hasPrefix("lo") || interface.ifa_addr.pointee.sa_family != UInt8(AF_LINK) {
                continue
            }
            
            if let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self) {
                bytesReceived += UInt64(data.pointee.ifi_ibytes)
                bytesSent += UInt64(data.pointee.ifi_obytes)
            }
        }
        
        return NetworkData(bytesReceived: bytesReceived, bytesSent: bytesSent, timestamp: Date())
    }
}
