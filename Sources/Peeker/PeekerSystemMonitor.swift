import Foundation
import MachO
import Network
import SystemConfiguration

public class PeekerSystemMonitor {
    private var pathMonitor: NWPathMonitor?
    private var currentPath: NWPath?
    private var networkSpeedCalculator: NetworkSpeedCalculator
    private var cpuMonitor: CPUMonitor
    private var memoryMonitor: MemoryMonitor
    
    public init() {
        self.networkSpeedCalculator = NetworkSpeedCalculator()
        self.cpuMonitor = CPUMonitor()
        self.memoryMonitor = MemoryMonitor()
    }
    
    public func startMonitoring() {
        startNetworkMonitoring()
        cpuMonitor.startMonitoring()
        memoryMonitor.startMonitoring()
    }
    
    public func stopMonitoring() {
        pathMonitor?.cancel()
        pathMonitor = nil
        cpuMonitor.stopMonitoring()
        memoryMonitor.stopMonitoring()
    }
    
    public func getCurrentMetrics() -> PeekerMetrics {
        let memory = memoryMonitor.getCurrentMemoryInfo()
        let cpu = cpuMonitor.getCurrentCPUInfo()
        let network = getCurrentNetworkInfo()
        
        return PeekerMetrics(
            memory: memory,
            cpu: cpu,
            network: network,
            timestamp: Date()
        )
    }
    
    private func startNetworkMonitoring() {
        pathMonitor = NWPathMonitor()
        let queue = DispatchQueue(label: "PeekerNetworkMonitor", qos: .utility)
        
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            self?.currentPath = path
        }
        
        pathMonitor?.start(queue: queue)
        networkSpeedCalculator.startMonitoring()
    }
    
    private func getCurrentNetworkInfo() -> PeekerMetrics.NetworkInfo {
        let isConnected = currentPath?.status == .satisfied
        let connectionType = getConnectionType()
        let (downloadSpeed, uploadSpeed) = networkSpeedCalculator.getCurrentSpeeds()
        let signalStrength = getSignalStrength()
        
        return PeekerMetrics.NetworkInfo(
            isConnected: isConnected,
            connectionType: connectionType,
            downloadSpeed: downloadSpeed,
            uploadSpeed: uploadSpeed,
            signalStrength: signalStrength
        )
    }
    
    private func getConnectionType() -> String {
        guard let path = currentPath else { return "Unknown" }
        
        if path.usesInterfaceType(.wifi) {
            return "Wi-Fi"
        } else if path.usesInterfaceType(.cellular) {
            return "Cellular"
        } else if path.usesInterfaceType(.wiredEthernet) {
            return "Ethernet"
        } else if path.usesInterfaceType(.other) {
            return "Other"
        } else {
            return "Unknown"
        }
    }
    
    private func getSignalStrength() -> PeekerMetrics.NetworkInfo.NetworkSignalStrength? {
        // iOS에서는 신호 강도를 직접 가져올 수 없으므로 네트워크 속도를 기반으로 추정
        let (download, _) = networkSpeedCalculator.getCurrentSpeeds()
        
        switch download {
        case 0..<100: return .poor
        case 100..<1000: return .fair
        case 1000..<5000: return .good
        default: return .excellent
        }
    }
}
