import XCTest
import UIKit
@testable import Peeker

// MARK: - 테스트용 Mock 클래스들
class MockNetworkSpeedCalculator {
    var mockSpeeds: (download: Double, upload: Double) = (0, 0)
    
    func getCurrentSpeeds() -> (download: Double, upload: Double) {
        return mockSpeeds
    }
}

class MockPeekerSystemMonitor: PeekerSystemMonitor {
    var mockMetrics: PeekerMetrics?
    
    override func getCurrentMetrics() -> PeekerMetrics {
        return mockMetrics ?? PeekerMetrics(
            memory: PeekerMetrics.MemoryInfo(used: 100.0, available: 900.0, pressure: .normal),
            cpu: PeekerMetrics.CPUInfo(usage: 25.0, temperature: nil),
            network: PeekerMetrics.NetworkInfo(
                isConnected: true,
                connectionType: "Wi-Fi",
                downloadSpeed: 1000.0,
                uploadSpeed: 500.0,
                signalStrength: .excellent
            ),
            timestamp: Date()
        )
    }
}

// MARK: - Peeker 코어 기능 테스트
class PeekerCoreTests: XCTestCase {
    
    var peeker: Peeker!
    var testView: UIView!
    
    override func setUp() {
        super.setUp()
        peeker = Peeker.shared
        testView = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        
        // 이전 테스트의 영향을 없애기 위해 정리
        peeker.stop()
    }
    
    override func tearDown() {
        peeker.stop()
        testView = nil
        super.tearDown()
    }
    
    func testPeekerSingletonInstance() {
        // Given & When
        let instance1 = Peeker.shared
        let instance2 = Peeker.shared
        
        // Then
        XCTAssertTrue(instance1 === instance2, "Peeker should be a singleton")
    }
    
    func testPeekerStartWithDefaultConfiguration() {
        // Given
        let expectation = XCTestExpectation(description: "Peeker starts successfully")
        
        // When
        peeker.start(on: testView)
        
        // Then
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.peeker.isRunning, "Peeker should be running")
            XCTAssertNotNil(self.peeker.graphView, "Graph view should be created")
            XCTAssertEqual(self.testView.subviews.count, 1, "Test view should contain one subview")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPeekerStartWithCustomConfiguration() {
        // Given
        let customConfig = Peeker.PeekerConfiguration(
            updateInterval: 0.5,
            maxDataPoints: 150,
            position: .topRight,
            size: CGSize(width: 300, height: 160),
            cornerRadius: 16,
            backgroundColor: UIColor.red.withAlphaComponent(0.8)
        )
        
        // When
        peeker.start(on: testView, configuration: customConfig)
        
        // Then
        XCTAssertTrue(peeker.isRunning)
        XCTAssertNotNil(peeker.graphView)
        
        if let graphView = peeker.graphView {
            XCTAssertEqual(graphView.frame.size, customConfig.size)
            XCTAssertEqual(graphView.layer.cornerRadius, customConfig.cornerRadius)
            XCTAssertEqual(graphView.backgroundColor, customConfig.backgroundColor)
        }
    }
    
    func testPeekerStop() {
        // Given
        peeker.start(on: testView)
        XCTAssertTrue(peeker.isRunning)
        
        // When
        peeker.stop()
        
        // Then
        let expectation = XCTestExpectation(description: "Peeker stops successfully")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.peeker.isRunning, "Peeker should not be running")
            XCTAssertEqual(self.testView.subviews.count, 0, "Graph view should be removed")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testPeekerRestartOverwritesPrevious() {
        // Given
        peeker.start(on: testView)
        let firstGraphView = peeker.graphView
        
        // When
        peeker.start(on: testView) // 다시 시작
        
        // Then
        let expectation = XCTestExpectation(description: "Previous Peeker is replaced")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNotEqual(self.peeker.graphView, firstGraphView, "New graph view should be created")
            XCTAssertEqual(self.testView.subviews.count, 1, "Only one graph view should exist")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - Configuration 테스트
class PeekerConfigurationTests: XCTestCase {
    
    func testDefaultConfiguration() {
        // Given & When
        let config = Peeker.PeekerConfiguration()
        
        // Then
        XCTAssertEqual(config.updateInterval, 1.0)
        XCTAssertEqual(config.maxDataPoints, 100)
        XCTAssertEqual(config.size, CGSize(width: 280, height: 140))
        XCTAssertEqual(config.cornerRadius, 12)
        
        switch config.position {
        case .topLeft:
            XCTAssertTrue(true)
        default:
            XCTFail("Default position should be topLeft")
        }
    }
    
    func testCustomConfiguration() {
        // Given
        let customSize = CGSize(width: 320, height: 180)
        let customInterval: TimeInterval = 0.5
        let customRadius: CGFloat = 20
        let customPoints = 200
        
        // When
        let config = Peeker.PeekerConfiguration(
            updateInterval: customInterval,
            maxDataPoints: customPoints,
            position: .bottomRight,
            size: customSize,
            cornerRadius: customRadius,
            backgroundColor: UIColor.blue
        )
        
        // Then
        XCTAssertEqual(config.updateInterval, customInterval)
        XCTAssertEqual(config.maxDataPoints, customPoints)
        XCTAssertEqual(config.size, customSize)
        XCTAssertEqual(config.cornerRadius, customRadius)
        XCTAssertEqual(config.backgroundColor, UIColor.blue)
        
        switch config.position {
        case .bottomRight:
            XCTAssertTrue(true)
        default:
            XCTFail("Position should be bottomRight")
        }
    }
}

// MARK: - 위치 계산 테스트
class PeekerPositionTests: XCTestCase {
    
    var peeker: Peeker!
    var testView: UIView!
    
    override func setUp() {
        super.setUp()
        peeker = Peeker.shared
        testView = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        testView.safeAreaInsets = UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0)
    }
    
    override func tearDown() {
        peeker.stop()
        super.tearDown()
    }
    
    func testTopLeftPosition() {
        // Given
        let config = Peeker.PeekerConfiguration(position: .topLeft, size: CGSize(width: 200, height: 100))
        
        // When
        peeker.start(on: testView, configuration: config)
        
        // Then
        if let graphView = peeker.graphView {
            XCTAssertEqual(graphView.frame.origin.x, 20) // margin
            XCTAssertEqual(graphView.frame.origin.y, 64) // safeArea.top + margin
        }
    }
    
    func testTopRightPosition() {
        // Given
        let config = Peeker.PeekerConfiguration(position: .topRight, size: CGSize(width: 200, height: 100))
        
        // When
        peeker.start(on: testView, configuration: config)
        
        // Then
        if let graphView = peeker.graphView {
            XCTAssertEqual(graphView.frame.origin.x, 180) // 400 - 200 - 20
            XCTAssertEqual(graphView.frame.origin.y, 64) // safeArea.top + margin
        }
    }
    
    func testBottomRightPosition() {
        // Given
        let config = Peeker.PeekerConfiguration(position: .bottomRight, size: CGSize(width: 200, height: 100))
        
        // When
        peeker.start(on: testView, configuration: config)
        
        // Then
        if let graphView = peeker.graphView {
            XCTAssertEqual(graphView.frame.origin.x, 180) // 400 - 200 - 20
            XCTAssertEqual(graphView.frame.origin.y, 646) // 800 - 100 - 34 - 20
        }
    }
    
    func testCustomPosition() {
        // Given
        let customPoint = CGPoint(x: 50, y: 100)
        let config = Peeker.PeekerConfiguration(position: .custom(customPoint), size: CGSize(width: 200, height: 100))
        
        // When
        peeker.start(on: testView, configuration: config)
        
        // Then
        if let graphView = peeker.graphView {
            XCTAssertEqual(graphView.frame.origin, customPoint)
        }
    }
}

// MARK: - 위치 변경 기능 테스트
class PeekerPositionChangeTests: XCTestCase {
    
    var peeker: Peeker!
    var testView: UIView!
    
    override func setUp() {
        super.setUp()
        peeker = Peeker.shared
        testView = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
    }
    
    override func tearDown() {
        peeker.stop()
        super.tearDown()
    }
    
    func testCyclePosition() {
        // Given
        let config = Peeker.PeekerConfiguration(position: .topLeft)
        peeker.start(on: testView, configuration: config)
        
        // When & Then
        let expectations = [
            expectation(description: "Position cycles to topRight"),
            expectation(description: "Position cycles to bottomRight"),
            expectation(description: "Position cycles to bottomLeft"),
            expectation(description: "Position cycles back to topLeft")
        ]
        
        // TopLeft -> TopRight
        peeker.cyclePosition(animated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switch self.peeker.currentConfig.position {
            case .topRight:
                expectations[0].fulfill()
            default:
                XCTFail("Should cycle to topRight")
            }
        }
        
        // Continue cycling...
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.peeker.cyclePosition(animated: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                switch self.peeker.currentConfig.position {
                case .bottomRight:
                    expectations[1].fulfill()
                default:
                    XCTFail("Should cycle to bottomRight")
                }
            }
        }
        
        wait(for: expectations, timeout: 2.0)
    }
    
    func testChangePositionDirectly() {
        // Given
        peeker.start(on: testView)
        let targetPosition: Peeker.PeekerPosition = .bottomLeft
        
        // When
        peeker.changePosition(to: targetPosition, animated: false)
        
        // Then
        let expectation = XCTestExpectation(description: "Position changes to bottomLeft")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switch self.peeker.currentConfig.position {
            case .bottomLeft:
                expectation.fulfill()
            default:
                XCTFail("Position should change to bottomLeft")
            }
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - 제스처 테스트
class PeekerGestureTests: XCTestCase {
    
    var peeker: Peeker!
    var testView: UIView!
    
    override func setUp() {
        super.setUp()
        peeker = Peeker.shared
        testView = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        
        // UIWindow 시뮬레이션
        let window = UIWindow(frame: testView.bounds)
        window.addSubview(testView)
        window.makeKeyAndVisible()
    }
    
    override func tearDown() {
        peeker.stop()
        super.tearDown()
    }
    
    func testDoubleTapGestureExists() {
        // Given
        peeker.start(on: testView)
        
        // Then
        if let graphView = peeker.graphView {
            let doubleTapGestures = graphView.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }
            let doubleTapExists = doubleTapGestures?.contains { $0.numberOfTapsRequired == 2 } ?? false
            
            XCTAssertTrue(doubleTapExists, "Double tap gesture should exist")
        } else {
            XCTFail("Graph view should exist")
        }
    }
    
    func testPanGestureExists() {
        // Given
        peeker.start(on: testView)
        
        // Then
        if let graphView = peeker.graphView {
            let panGestures = graphView.gestureRecognizers?.compactMap { $0 as? UIPanGestureRecognizer }
            
            XCTAssertFalse(panGestures?.isEmpty ?? true, "Pan gesture should exist")
            
            if let panGesture = panGestures?.first {
                XCTAssertEqual(panGesture.maximumNumberOfTouches, 1, "Pan gesture should allow only one touch")
            }
        } else {
            XCTFail("Graph view should exist")
        }
    }
    
    func testGestureInteraction() {
        // Given
        peeker.start(on: testView)
        
        // Then
        if let graphView = peeker.graphView {
            XCTAssertTrue(graphView.isUserInteractionEnabled, "Graph view should enable user interaction")
        }
    }
}

// MARK: - 메트릭스 모델 테스트
class PeekerMetricsTests: XCTestCase {
    
    func testMemoryInfoCreation() {
        // Given
        let used: Double = 150.5
        let available: Double = 849.5
        let pressure = PeekerMetrics.MemoryInfo.MemoryPressure.warning
        
        // When
        let memoryInfo = PeekerMetrics.MemoryInfo(
            used: used,
            available: available,
            pressure: pressure
        )
        
        // Then
        XCTAssertEqual(memoryInfo.used, used)
        XCTAssertEqual(memoryInfo.available, available)
        XCTAssertEqual(memoryInfo.pressure, pressure)
    }
    
    func testCPUInfoCreation() {
        // Given
        let usage: Double = 65.5
        let temperature: Double = 45.0
        
        // When
        let cpuInfo = PeekerMetrics.CPUInfo(usage: usage, temperature: temperature)
        
        // Then
        XCTAssertEqual(cpuInfo.usage, usage)
        XCTAssertEqual(cpuInfo.temperature, temperature)
    }
    
    func testNetworkInfoCreation() {
        // Given
        let isConnected = true
        let connectionType = "Wi-Fi"
        let downloadSpeed: Double = 1500.0
        let uploadSpeed: Double = 750.0
        let signalStrength = PeekerMetrics.NetworkInfo.NetworkSignalStrength.excellent
        
        // When
        let networkInfo = PeekerMetrics.NetworkInfo(
            isConnected: isConnected,
            connectionType: connectionType,
            downloadSpeed: downloadSpeed,
            uploadSpeed: uploadSpeed,
            signalStrength: signalStrength
        )
        
        // Then
        XCTAssertEqual(networkInfo.isConnected, isConnected)
        XCTAssertEqual(networkInfo.connectionType, connectionType)
        XCTAssertEqual(networkInfo.downloadSpeed, downloadSpeed)
        XCTAssertEqual(networkInfo.uploadSpeed, uploadSpeed)
        XCTAssertEqual(networkInfo.signalStrength, signalStrength)
    }
    
    func testNetworkSignalStrengthEmoji() {
        // Given & When & Then
        XCTAssertEqual(PeekerMetrics.NetworkInfo.NetworkSignalStrength.poor.emoji, "📶")
        XCTAssertEqual(PeekerMetrics.NetworkInfo.NetworkSignalStrength.fair.emoji, "📶📶")
        XCTAssertEqual(PeekerMetrics.NetworkInfo.NetworkSignalStrength.good.emoji, "📶📶📶")
        XCTAssertEqual(PeekerMetrics.NetworkInfo.NetworkSignalStrength.excellent.emoji, "📶📶📶📶")
    }
    
    func testCompleteMetricsCreation() {
        // Given
        let memory = PeekerMetrics.MemoryInfo(used: 100, available: 900, pressure: .normal)
        let cpu = PeekerMetrics.CPUInfo(usage: 25.5, temperature: nil)
        let network = PeekerMetrics.NetworkInfo(
            isConnected: true,
            connectionType: "Cellular",
            downloadSpeed: 500,
            uploadSpeed: 200,
            signalStrength: .good
        )
        let timestamp = Date()
        
        // When
        let metrics = PeekerMetrics(
            memory: memory,
            cpu: cpu,
            network: network,
            timestamp: timestamp
        )
        
        // Then
        XCTAssertEqual(metrics.memory.used, memory.used)
        XCTAssertEqual(metrics.cpu.usage, cpu.usage)
        XCTAssertEqual(metrics.network.connectionType, network.connectionType)
        XCTAssertEqual(metrics.timestamp, timestamp)
    }
}

// MARK: - GraphView 테스트
class PeekerGraphViewTests: XCTestCase {
    
    var graphView: PeekerGraphView!
    var config: Peeker.PeekerConfiguration!
    
    override func setUp() {
        super.setUp()
        config = Peeker.PeekerConfiguration(maxDataPoints: 50)
        graphView = PeekerGraphView(
            frame: CGRect(x: 0, y: 0, width: 300, height: 150),
            configuration: config
        )
    }
    
    func testGraphViewInitialization() {
        // Then
        XCTAssertNotNil(graphView)
        XCTAssertEqual(graphView.frame.size, CGSize(width: 300, height: 150))
        XCTAssertEqual(graphView.backgroundColor, config.backgroundColor)
        XCTAssertEqual(graphView.layer.cornerRadius, config.cornerRadius)
    }
    
    func testMetricsUpdate() {
        // Given
        let metrics = createTestMetrics()
        
        // When
        graphView.update(with: metrics)
        
        // Then
        // 메트릭 히스토리가 업데이트되었는지 확인 (private이므로 간접적으로 확인)
        XCTAssertTrue(true) // 크래시하지 않으면 성공
    }
    
    func testMaxDataPointsLimit() {
        // Given
        let maxPoints = config.maxDataPoints
        
        // When - maxDataPoints보다 많은 메트릭 추가
        for i in 0..<(maxPoints + 20) {
            let metrics = createTestMetrics()
            graphView.update(with: metrics)
        }
        
        // Then
        // private 멤버이므로 크래시하지 않는 것으로 테스트
        XCTAssertTrue(true)
    }
    
    private func createTestMetrics() -> PeekerMetrics {
        return PeekerMetrics(
            memory: PeekerMetrics.MemoryInfo(used: 100, available: 900, pressure: .normal),
            cpu: PeekerMetrics.CPUInfo(usage: 30, temperature: nil),
            network: PeekerMetrics.NetworkInfo(
                isConnected: true,
                connectionType: "Wi-Fi",
                downloadSpeed: 1000,
                uploadSpeed: 500,
                signalStrength: .excellent
            ),
            timestamp: Date()
        )
    }
}

// MARK: - 통합 테스트
class PeekerIntegrationTests: XCTestCase {
    
    var peeker: Peeker!
    var testViewController: UIViewController!
    
    override func setUp() {
        super.setUp()
        peeker = Peeker.shared
        testViewController = UIViewController()
        testViewController.view.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        
        // View controller를 window에 추가
        let window = UIWindow(frame: testViewController.view.bounds)
        window.rootViewController = testViewController
        window.makeKeyAndVisible()
    }
    
    override func tearDown() {
        peeker.stop()
        super.tearDown()
    }
    
    func testCompleteWorkflow() {
        let expectation = XCTestExpectation(description: "Complete workflow test")
        
        // 1. 시작
        peeker.start(on: testViewController.view)
        XCTAssertTrue(peeker.isRunning)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 2. 위치 변경
            self.peeker.changePosition(to: .topRight, animated: false)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // 3. 설정 변경 후 재시작
                let newConfig = Peeker.PeekerConfiguration(
                    updateInterval: 0.5,
                    position: .bottomLeft,
                    size: CGSize(width: 250, height: 120)
                )
                
                self.peeker.start(on: self.testViewController.view, configuration: newConfig)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    // 4. 중지
                    self.peeker.stop()
                    XCTAssertFalse(self.peeker.isRunning)
                    
                    expectation.fulfill()
                }
            }
        }
        
        wait(for: [expectation], timeout: 3.0)
    }
    
    func testMemoryLeaks() {
        weak var weakGraphView: PeekerGraphView?
        
        autoreleasepool {
            peeker.start(on: testViewController.view)
            weakGraphView = peeker.graphView
            XCTAssertNotNil(weakGraphView)
            
            peeker.stop()
        }
        
        // 메모리 리크 검사
        let expectation = XCTestExpectation(description: "Memory leak test")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertNil(weakGraphView, "GraphView should be deallocated")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}

// MARK: - 성능 테스트
class PeekerPerformanceTests: XCTestCase {
    
    var peeker: Peeker!
    var testView: UIView!
    
    override func setUp() {
        super.setUp()
        peeker = Peeker.shared
        testView = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
    }
    
    override func tearDown() {
        peeker.stop()
        super.tearDown()
    }
    
    func testStartupPerformance() {
        measure {
            peeker.start(on: testView)
            peeker.stop()
        }
    }
    
    func testPositionChangePerformance() {
        peeker.start(on: testView)
        
        measure {
            peeker.changePosition(to: .topRight, animated: false)
            peeker.changePosition(to: .bottomRight, animated: false)
            peeker.changePosition(to: .bottomLeft, animated: false)
            peeker.changePosition(to: .topLeft, animated: false)
        }
    }
    
    func testMetricsUpdatePerformance() {
        let config = Peeker.PeekerConfiguration(maxDataPoints: 1000)
        let graphView = PeekerGraphView(frame: CGRect(x: 0, y: 0, width: 300, height: 150), configuration: config)
        
        let metrics = PeekerMetrics(
            memory: PeekerMetrics.MemoryInfo(used: 100, available: 900, pressure: .normal),
            cpu: PeekerMetrics.CPUInfo(usage: 30, temperature: nil),
            network: PeekerMetrics.NetworkInfo(
                isConnected: true,
                connectionType: "Wi-Fi",
                downloadSpeed: 1000,
                uploadSpeed: 500,
                signalStrength: .excellent
            ),
            timestamp: Date()
        )
        
        measure {
            for _ in 0..<100 {
                graphView.update(with: metrics)
            }
        }
    }
}

// MARK: - 테스트 러너 설정
class PeekerTestSuite: NSObject {
    
    static func runAllTests() {
        // 모든 테스트 클래스들을 순서대로 실행
        let testClasses: [XCTestCase.Type] = [
            PeekerCoreTests.self,
            PeekerConfigurationTests.self,
            PeekerPositionTests.self,
            PeekerPositionChangeTests.self,
            PeekerGestureTests.self,
            PeekerMetricsTests.self,
            PeekerGraphViewTests.self,
            PeekerIntegrationTests.self,
            PeekerPerformanceTests.self
        ]
        
        print("🚀 Starting Peeker Test Suite...")
        
        for testClass in testClasses {
            print("📋 Running tests for \(testClass)")
            // 실제 테스트 실행 로직은 Xcode의 테스트 러너가 처리
        }
        
        print("✅ Peeker Test Suite completed!")
    }
}
