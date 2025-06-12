import UIKit

public class PeekerGraphView: UIView {
    private var metricsHistory: [PeekerMetrics] = []
    private let maxDataPoints: Int
    private let configuration: Peeker.PeekerConfiguration
    
    // MARK: - UI Components
    private lazy var containerStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var headerStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        return stack
    }()
    
    private lazy var memoryLabel: UILabel = createLabel(size: 11, weight: .medium)
    private lazy var cpuLabel: UILabel = createLabel(size: 11, weight: .medium)
    private lazy var networkLabel: UILabel = createLabel(size: 10, weight: .regular, lines: 2)
    private lazy var statusLabel: UILabel = createLabel(size: 10, weight: .medium, alignment: .right)
    
    private lazy var graphContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    // MARK: - Initialization
    public init(frame: CGRect, configuration: Peeker.PeekerConfiguration) {
        self.maxDataPoints = configuration.maxDataPoints
        self.configuration = configuration
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = configuration.backgroundColor
        layer.cornerRadius = configuration.cornerRadius
        layer.borderWidth = 0.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        
        // Shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.3
        
        setupHierarchy()
        setupConstraints()
    }
    
    private func setupHierarchy() {
        addSubview(containerStackView)
        
        headerStackView.addArrangedSubview(createInfoStack(with: [memoryLabel, cpuLabel]))
        headerStackView.addArrangedSubview(createInfoStack(with: [networkLabel, statusLabel]))
        
        containerStackView.addArrangedSubview(headerStackView)
        containerStackView.addArrangedSubview(graphContainerView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerStackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            containerStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            containerStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            containerStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            
            headerStackView.heightAnchor.constraint(equalToConstant: 44),
            graphContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
    }
    
    private func createLabel(size: CGFloat, weight: UIFont.Weight, alignment: NSTextAlignment = .left, lines: Int = 1) -> UILabel {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        label.textColor = .white
        label.textAlignment = alignment
        label.numberOfLines = lines
        return label
    }
    
    private func createInfoStack(with labels: [UILabel]) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: labels)
        stack.axis = .vertical
        stack.spacing = 2
        return stack
    }
    
    // MARK: - Public Methods
    public func update(with metrics: PeekerMetrics) {
        metricsHistory.append(metrics)
        if metricsHistory.count > maxDataPoints {
            metricsHistory.removeFirst()
        }
        
        updateLabels(with: metrics)
        setNeedsDisplay()
    }
    
    // MARK: - Private Methods
    private func updateLabels(with metrics: PeekerMetrics) {
        // Memory
        let memoryColor = colorForMemoryPressure(metrics.memory.pressure)
        let memoryText = String(format: "MEM: %.1f MB", metrics.memory.used)
        memoryLabel.attributedText = NSAttributedString(
            string: memoryText,
            attributes: [.foregroundColor: memoryColor]
        )
        
        // CPU
        let cpuColor = colorForCPUUsage(metrics.cpu.usage)
        let cpuText = String(format: "CPU: %.1f%%", metrics.cpu.usage)
        cpuLabel.attributedText = NSAttributedString(
            string: cpuText,
            attributes: [.foregroundColor: cpuColor]
        )
        
        // Network
        let downloadText = String(format: "↓ %.1f KB/s", metrics.network.downloadSpeed)
        let uploadText = String(format: "↑ %.1f KB/s", metrics.network.uploadSpeed)
        networkLabel.text = "\(downloadText)\n\(uploadText)"
        
        // Status
        let statusIcon = metrics.network.isConnected ? "🟢" : "🔴"
        let signalInfo = metrics.network.signalStrength?.emoji ?? ""
        statusLabel.text = "\(statusIcon) \(metrics.network.connectionType) \(signalInfo)"
    }
    
    private func colorForMemoryPressure(_ pressure: PeekerMetrics.MemoryInfo.MemoryPressure) -> UIColor {
        switch pressure {
        case .normal: return .systemGreen
        case .warning: return .systemYellow
        case .critical: return .systemRed
        }
    }
    
    private func colorForCPUUsage(_ usage: Double) -> UIColor {
        switch usage {
        case 0..<50: return .systemGreen
        case 50..<80: return .systemYellow
        default: return .systemRed
        }
    }
    
    // MARK: - Drawing
    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard metricsHistory.count > 1 else { return }
        
        let graphRect = graphContainerView.frame
        guard !graphRect.isEmpty else { return }
        
        drawGraphs(in: graphRect)
    }
    
    private func drawGraphs(in rect: CGRect) {
        let memoryRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.4)
        let cpuRect = CGRect(x: rect.minX, y: rect.minY + rect.height * 0.4, width: rect.width, height: rect.height * 0.3)
        let networkRect = CGRect(x: rect.minX, y: rect.minY + rect.height * 0.7, width: rect.width, height: rect.height * 0.3)
        
        drawMemoryGraph(in: memoryRect)
        drawCPUGraph(in: cpuRect)
        drawNetworkGraph(in: networkRect)
    }
    
    private func drawMemoryGraph(in rect: CGRect) {
        let memoryValues = metricsHistory.map { $0.memory.used }
        let maxMemory = memoryValues.max() ?? 1
        
        drawLineGraph(
            values: memoryValues,
            in: rect,
            maxValue: maxMemory,
            color: .systemGreen,
            fillColor: UIColor.systemGreen.withAlphaComponent(0.2)
        )
    }
    
    private func drawCPUGraph(in rect: CGRect) {
        let cpuValues = metricsHistory.map { $0.cpu.usage }
        
        drawLineGraph(
            values: cpuValues,
            in: rect,
            maxValue: 100,
            color: .systemRed,
            fillColor: UIColor.systemRed.withAlphaComponent(0.2)
        )
    }
    
    private func drawNetworkGraph(in rect: CGRect) {
        let downloadValues = metricsHistory.map { $0.network.downloadSpeed }
        let uploadValues = metricsHistory.map { $0.network.uploadSpeed }
        
        let maxDownload = downloadValues.max() ?? 1
        let maxUpload = uploadValues.max() ?? 1
        let maxValue = max(maxDownload, maxUpload, 1)
        
        // Download graph
        drawLineGraph(values: downloadValues, in: rect, maxValue: maxValue, color: .systemBlue)
        
        // Upload graph
        drawLineGraph(values: uploadValues, in: rect, maxValue: maxValue, color: .systemOrange)
    }
    
    private func drawLineGraph(values: [Double], in rect: CGRect, maxValue: Double, color: UIColor, fillColor: UIColor? = nil) {
        guard values.count > 1 else { return }
        
        let path = UIBezierPath()
        let stepX = rect.width / CGFloat(values.count - 1)
        
        for (index, value) in values.enumerated() {
            let x = rect.minX + CGFloat(index) * stepX
            let normalizedValue = CGFloat(value / maxValue)
            let y = rect.maxY - normalizedValue * rect.height
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        // Fill area under curve if fillColor is provided
        if let fillColor = fillColor {
            let fillPath = path.copy() as! UIBezierPath
            fillPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            fillPath.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            fillPath.close()
            
            fillColor.setFill()
            fillPath.fill()
        }
        
        // Draw line
        color.setStroke()
        path.lineWidth = 2
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }
}
