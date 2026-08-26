import SwiftUI
import FormCoachCore

public struct StatusBadge: View {
    public let level: TrackingConfidenceLevel
    
    public init(level: TrackingConfidenceLevel) {
        self.level = level
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)
            
            Text(level.displayText.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(indicatorColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(indicatorColor.opacity(0.15))
        .cornerRadius(12)
    }
    
    private var indicatorColor: Color {
        switch level {
        case .good: return .green
        case .limited: return .orange
        case .insufficient: return .red
        }
    }
}

public struct MetricCard: View {
    public let title: String
    public let value: String
    public let unit: String?
    public let subtitle: String?
    public let highlightColor: Color
    
    public init(
        title: String,
        value: String,
        unit: String? = nil,
        subtitle: String? = nil,
        highlightColor: Color = .green
    ) {
        self.title = title
        self.value = value
        self.unit = unit
        self.subtitle = subtitle
        self.highlightColor = highlightColor
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                
                if let u = unit {
                    Text(u)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
            
            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.12))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

public struct PrimaryGymButton: View {
    public let title: String
    public let icon: String?
    public let color: Color
    public let action: () -> Void
    
    public init(
        title: String,
        icon: String? = nil,
        color: Color = .green,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let i = icon {
                    Image(systemName: i)
                        .font(.system(size: 20, weight: .bold))
                }
                
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(color)
            .cornerRadius(16)
            .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
