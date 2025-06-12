//
//  CPUMonitor.swift
//  Peeker
//
//  Created by duri on 6/12/25.
//

import Foundation

class CPUMonitor {
    private var isMonitoring = false
    private var cpuUsage: Double = 0
    private let monitorQueue = DispatchQueue(label: "CPUMonitor", qos: .utility)
    
    func startMonitoring() {
        isMonitoring = true
    }
    
    func stopMonitoring() {
        isMonitoring = false
    }
    
    func getCurrentCPUInfo() -> PeekerMetrics.CPUInfo {
        let usage = getCPUUsage()
        return PeekerMetrics.CPUInfo(usage: usage, temperature: nil)
    }
    
    private func getCPUUsage() -> Double {
        var info = task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0 }
        
        // Thread 정보를 이용한 더 정확한 CPU 사용률 계산
        return getThreadCPUUsage()
    }
    
    private func getThreadCPUUsage() -> Double {
        var threadList: thread_act_array_t?
        var threadCount = mach_msg_type_number_t()
        
        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        guard result == KERN_SUCCESS, let threads = threadList else { return 0 }
        
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.size))
        }
        
        var totalCPUUsage: Double = 0
        
        for i in 0..<Int(threadCount) {
            var threadInfo = thread_basic_info()
            var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
            
            let threadResult = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                }
            }
            
            if threadResult == KERN_SUCCESS {
                let cpuUsage = Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100
                totalCPUUsage += cpuUsage
            }
        }
        
        return min(totalCPUUsage, 100.0)
    }
}
