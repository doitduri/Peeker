//
//  MemoryMonitor.swift
//  Peeker
//
//  Created by duri on 6/12/25.
//

import Foundation

class MemoryMonitor {
    func startMonitoring() { }
    
    func stopMonitoring() { }
    
    func getCurrentMemoryInfo() -> PeekerMetrics.MemoryInfo {
        let memoryUsage = getMemoryUsage()
        let availableMemory = getAvailableMemory()
        let pressure = determineMemoryPressure(used: memoryUsage, available: availableMemory)
        
        return PeekerMetrics.MemoryInfo(
            used: memoryUsage,
            available: availableMemory,
            pressure: pressure
        )
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / (1024 * 1024) // bytes to MB
    }
    
    private func getAvailableMemory() -> Double {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let usedMemory = getMemoryUsage() * 1024 * 1024 // MB to bytes
        let availableMemory = Double(totalMemory) - usedMemory
        return availableMemory / (1024 * 1024) // bytes to MB
    }
    
    private func determineMemoryPressure(used: Double, available: Double) -> PeekerMetrics.MemoryInfo.MemoryPressure {
        let totalMemory = used + available
        let usagePercentage = (used / totalMemory) * 100
        
        switch usagePercentage {
        case 0..<70:
            return .normal
        case 70..<85:
            return .warning
        default:
            return .critical
        }
    }
    
    private func getSystemMemoryInfo() -> (free: UInt64, used: UInt64)? {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return nil }
        
        let pageSize = UInt64(vm_kernel_page_size)
        let freePages = UInt64(info.free_count)
        let usedPages = UInt64(info.active_count + info.inactive_count + info.wire_count)
        
        return (
            free: freePages * pageSize,
            used: usedPages * pageSize
        )
    }
}
