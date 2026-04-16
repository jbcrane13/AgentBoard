import SwiftUI

/// Priority levels for tasks and epics
public enum Priority: Int, Codable, CaseIterable, Sendable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
    
    public var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    public var icon: String {
        switch self {
        case .low: return "arrow.down.circle"
        case .medium: return "minus.circle"
        case .high: return "arrow.up.circle"
        case .critical: return "exclamationmark.triangle"
        }
    }
    
    public var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    public static func < (lhs: Priority, rhs: Priority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    /// Initialize from Int (for backward compatibility)
    public init(intValue: Int) {
        self = Priority(rawValue: intValue) ?? .medium
    }
}

// MARK: - View Extension for Priority Display

extension View {
    func priorityBadge(_ priority: Priority) -> some View {
        HStack(spacing: 4) {
            Image(systemName: priority.icon)
                .foregroundStyle(priority.color)
            Text(priority.label)
                .font(.caption)
                .foregroundStyle(priority.color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(priority.color.opacity(0.1))
        .cornerRadius(4)
    }
}
