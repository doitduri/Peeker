import UIKit
import Network
import MachO
import SystemConfiguration

public class Peeker {
    public static let shared = Peeker()
    
    private var timer: Timer?
    private var graphView: PeekerGraphView?
    private let monitor = PeekerSystemMonitor()
    private var currentConfig: PeekerConfiguration
    
    // MARK: - Configuration
    public struct PeekerConfiguration {
        public let updateInterval: TimeInterval
        public let maxDataPoints: Int
        public let position: PeekerPosition
        public let size: CGSize
        public let cornerRadius: CGFloat
        public let backgroundColor: UIColor
        
        public init(
            updateInterval: TimeInterval = 1.0,
            maxDataPoints: Int = 100,
            position: PeekerPosition = .topLeft,
            size: CGSize = CGSize(width: 280, height: 140),
            cornerRadius: CGFloat = 12,
            backgroundColor: UIColor = UIColor.black.withAlphaComponent(0.7)
        ) {
            self.updateInterval = updateInterval
            self.maxDataPoints = maxDataPoints
            self.position = position
            self.size = size
            self.cornerRadius = cornerRadius
            self.backgroundColor = backgroundColor
        }
    }
    
    public enum PeekerPosition {
        case topLeft, topRight, bottomLeft, bottomRight, custom(CGPoint)
    }
    
    private init(configuration: PeekerConfiguration = PeekerConfiguration()) {
        self.currentConfig = configuration
    }
    
    // MARK: - Public Methods
    public func start(on view: UIView? = nil, configuration: PeekerConfiguration? = nil) {
        // 이미 실행 중이면 중지 후 재시작
        if timer != nil {
            stop()
        }
        
        let targetView = view ?? findKeyWindow()
        guard let parentView = targetView else {
            print("Peeker: Unable to find target view")
            return
        }
        
        let finalConfig = configuration ?? currentConfig
        setupGraphView(on: parentView, with: finalConfig)
        startMonitoring(with: finalConfig)
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
        monitor.stopMonitoring()
        
        DispatchQueue.main.async { [weak self] in
            self?.graphView?.removeFromSuperview()
            self?.graphView = nil
        }
    }
    
    public var isRunning: Bool {
        return timer != nil
    }
    
    // MARK: - Private Methods
    private func findKeyWindow() -> UIView? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.keyWindow
        }
    }
    
    private func setupGraphView(on parentView: UIView, with config: PeekerConfiguration) {
        let frame = calculateFrame(for: parentView, config: config)
        let graphView = PeekerGraphView(frame: frame, configuration: config)
        
        parentView.addSubview(graphView)
        self.graphView = graphView
        
        // 드래그 제스처 추가
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.maximumNumberOfTouches = 1
        graphView.addGestureRecognizer(panGesture)
        
        // 더블 탭 제스처 추가 (위치 순환용)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        graphView.addGestureRecognizer(doubleTap)
        
        graphView.isUserInteractionEnabled = true
    }
    
    private func calculateFrame(for parentView: UIView, config: PeekerConfiguration) -> CGRect {
        let safeArea = parentView.safeAreaInsets
        let margin: CGFloat = 20
        
        switch config.position {
        case .topLeft:
            return CGRect(
                x: margin,
                y: safeArea.top + margin,
                width: config.size.width,
                height: config.size.height
            )
        case .topRight:
            return CGRect(
                x: parentView.bounds.width - config.size.width - margin,
                y: safeArea.top + margin,
                width: config.size.width,
                height: config.size.height
            )
        case .bottomLeft:
            return CGRect(
                x: margin,
                y: parentView.bounds.height - config.size.height - safeArea.bottom - margin,
                width: config.size.width,
                height: config.size.height
            )
        case .bottomRight:
            return CGRect(
                x: parentView.bounds.width - config.size.width - margin,
                y: parentView.bounds.height - config.size.height - safeArea.bottom - margin,
                width: config.size.width,
                height: config.size.height
            )
        case .custom(let point):
            return CGRect(origin: point, size: config.size)
        }
    }
    
    private func startMonitoring(with config: PeekerConfiguration) {
        monitor.startMonitoring()
        
        timer = Timer.scheduledTimer(withTimeInterval: config.updateInterval, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }
    
    private func updateMetrics() {
        let metrics = monitor.getCurrentMetrics()
        
        DispatchQueue.main.async { [weak self] in
            self?.graphView?.update(with: metrics)
        }
    }
    
    @objc private func handleDoubleTap() {
        guard let currentView = graphView?.superview else { return }
        
        // 현재 위치에서 다음 위치로 순환
        cyclePosition(animated: true)
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let graphView = self.graphView,
              let parentView = graphView.superview else { return }
        
        switch gesture.state {
        case .began:
            handlePanBegan(gesture, graphView: graphView)
            
        case .changed:
            handlePanChanged(gesture, graphView: graphView, parentView: parentView)
            
        case .ended, .cancelled:
            handlePanEnded(gesture, graphView: graphView, parentView: parentView)
            
        default:
            break
        }
    }
    
    private func handlePanBegan(_ gesture: UIPanGestureRecognizer, graphView: UIView) {
        // 드래그 시작 시 시각적 피드백
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseOut]) {
            graphView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            graphView.alpha = 0.9
        }
        
        // 햅틱 피드백
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func handlePanChanged(_ gesture: UIPanGestureRecognizer, graphView: UIView, parentView: UIView) {
        let translation = gesture.translation(in: parentView)
        
        // 현재 위치에서 이동
        let newCenter = CGPoint(
            x: graphView.center.x + translation.x,
            y: graphView.center.y + translation.y
        )
        
        // 화면 경계 내로 제한
        let constrainedCenter = constrainToSafeArea(point: newCenter, viewSize: graphView.bounds.size, parentView: parentView)
        graphView.center = constrainedCenter
        
        // 제스처 번역 리셋 (다음 변경사항을 위해)
        gesture.setTranslation(.zero, in: parentView)
    }
    
    private func handlePanEnded(_ gesture: UIPanGestureRecognizer, graphView: UIView, parentView: UIView) {
        let velocity = gesture.velocity(in: parentView)
        let currentCenter = graphView.center
        
        // 관성 효과 계산
        let dampingRatio: CGFloat = 0.8
        let velocityThreshold: CGFloat = 500
        
        var finalCenter = currentCenter
        
        // 빠른 제스처의 경우 관성 적용
        if abs(velocity.x) > velocityThreshold || abs(velocity.y) > velocityThreshold {
            let dampedVelocity = CGPoint(
                x: velocity.x * dampingRatio,
                y: velocity.y * dampingRatio
            )
            
            finalCenter = CGPoint(
                x: currentCenter.x + dampedVelocity.x * 0.1,
                y: currentCenter.y + dampedVelocity.y * 0.1
            )
        }
        
        // 자석 효과 - 모서리에 가까우면 스냅
        finalCenter = applyMagneticEffect(center: finalCenter, viewSize: graphView.bounds.size, parentView: parentView)
        
        // 화면 경계 제한
        finalCenter = constrainToSafeArea(point: finalCenter, viewSize: graphView.bounds.size, parentView: parentView)
        
        // 부드러운 애니메이션으로 최종 위치로 이동
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.8,
            options: [.curveEaseOut],
            animations: {
                graphView.center = finalCenter
                graphView.transform = .identity
                graphView.alpha = 1.0
            },
            completion: { [weak self] _ in
                // 최종 위치를 설정에 반영
                self?.updateConfigurationForDraggedPosition(center: finalCenter, parentView: parentView)
                
                // 마지막 햅틱 피드백
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
            }
        )
    }
    
    private func constrainToSafeArea(point: CGPoint, viewSize: CGSize, parentView: UIView) -> CGPoint {
        let safeArea = parentView.safeAreaInsets
        let margin: CGFloat = 10
        
        let minX = viewSize.width / 2 + margin
        let maxX = parentView.bounds.width - viewSize.width / 2 - margin
        let minY = safeArea.top + viewSize.height / 2 + margin
        let maxY = parentView.bounds.height - safeArea.bottom - viewSize.height / 2 - margin
        
        return CGPoint(
            x: max(minX, min(point.x, maxX)),
            y: max(minY, min(point.y, maxY))
        )
    }
    
    private func applyMagneticEffect(center: CGPoint, viewSize: CGSize, parentView: UIView) -> CGPoint {
        let safeArea = parentView.safeAreaInsets
        let magneticZone: CGFloat = 60 // 자석 효과 영역
        let margin: CGFloat = 20
        
        var magneticCenter = center
        
        // 좌측 가장자리에 자석 효과
        if center.x < margin + viewSize.width / 2 + magneticZone {
            magneticCenter.x = margin + viewSize.width / 2
        }
        
        // 우측 가장자리에 자석 효과
        if center.x > parentView.bounds.width - margin - viewSize.width / 2 - magneticZone {
            magneticCenter.x = parentView.bounds.width - margin - viewSize.width / 2
        }
        
        // 상단 가장자리에 자석 효과
        if center.y < safeArea.top + margin + viewSize.height / 2 + magneticZone {
            magneticCenter.y = safeArea.top + margin + viewSize.height / 2
        }
        
        // 하단 가장자리에 자석 효과
        if center.y > parentView.bounds.height - safeArea.bottom - margin - viewSize.height / 2 - magneticZone {
            magneticCenter.y = parentView.bounds.height - safeArea.bottom - margin - viewSize.height / 2
        }
        
        return magneticCenter
    }
    
    private func updateConfigurationForDraggedPosition(center: CGPoint, parentView: UIView) {
        // 드래그된 위치를 기반으로 설정 업데이트
        let viewSize = currentConfig.size
        let origin = CGPoint(
            x: center.x - viewSize.width / 2,
            y: center.y - viewSize.height / 2
        )
        
        // 새로운 위치로 설정 업데이트
        let newConfig = PeekerConfiguration(
            updateInterval: currentConfig.updateInterval,
            maxDataPoints: currentConfig.maxDataPoints,
            position: .custom(origin),
            size: currentConfig.size,
            cornerRadius: currentConfig.cornerRadius,
            backgroundColor: currentConfig.backgroundColor
        )
        
        updateConfiguration(newConfig)
    }
    
    private func getNextPosition() -> PeekerPosition {
        switch currentConfig.position {
        case .topLeft:
            return .topRight
        case .topRight:
            return .bottomRight
        case .bottomRight:
            return .bottomLeft
        case .bottomLeft:
            return .topLeft
        case .custom(_):
            return .topLeft // 커스텀 위치에서는 topLeft로 리셋
        }
    }
    
    private func animateToNewPosition(config newConfig: PeekerConfiguration, in parentView: UIView) {
        guard let currentGraphView = graphView else { return }
        
        let newFrame = calculateFrame(for: parentView, config: newConfig)
        
        // 위치 변경 애니메이션
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut],
            animations: {
                currentGraphView.frame = newFrame
                
                // 애니메이션 중 살짝 확대 효과
                currentGraphView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            },
            completion: { [weak self] _ in
                // 원래 크기로 복원
                UIView.animate(withDuration: 0.1) {
                    currentGraphView.transform = .identity
                }
                
                // 새로운 설정으로 업데이트
                self?.updateConfiguration(newConfig)
            }
        )
        
        // 햅틱 피드백 추가
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func updateConfiguration(_ newConfig: PeekerConfiguration) {
        currentConfig = newConfig
    }
    
    // MARK: - Public Methods for Position Control
    public func changePosition(to position: PeekerPosition, animated: Bool = true) {
        guard let parentView = graphView?.superview else { return }
        
        let newConfig = PeekerConfiguration(
            updateInterval: currentConfig.updateInterval,
            maxDataPoints: currentConfig.maxDataPoints,
            position: position,
            size: currentConfig.size,
            cornerRadius: currentConfig.cornerRadius,
            backgroundColor: currentConfig.backgroundColor
        )
        
        if animated {
            animateToNewPosition(config: newConfig, in: parentView)
        } else {
            graphView?.frame = calculateFrame(for: parentView, config: newConfig)
            updateConfiguration(newConfig)
        }
    }
    
    public func cyclePosition(animated: Bool = true) {
        let nextPosition = getNextPosition()
        changePosition(to: nextPosition, animated: animated)
    }
}

// MARK: - Extensions
extension Peeker {
    public func configure(_ configuration: PeekerConfiguration) -> Peeker {
        return Peeker(configuration: configuration)
    }
}
