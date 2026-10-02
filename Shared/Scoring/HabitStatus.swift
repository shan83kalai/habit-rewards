/// The state of one habit on one day. `unset` is a blank cell and scores nothing.
nonisolated enum HabitStatus: String, Codable, CaseIterable, Sendable {
    case unset
    case done
    case missed

    /// The Today screen's tap cycle: unset → done → missed → unset.
    var next: HabitStatus {
        switch self {
        case .unset: .done
        case .done: .missed
        case .missed: .unset
        }
    }
}
