import Foundation

/// Which children a habit is for, while it's being edited: everyone, or the ones ticked.
struct HabitAudience: Equatable {
    /// For every child, including ones added later.
    private(set) var isEveryone: Bool
    /// The children ticked when it isn't everyone's.
    private(set) var chosen: Set<UUID>
    /// What the habit was for before editing, to keep any archived children on it.
    private let original: [UUID]

    init(childIDs: [UUID]) {
        isEveryone = childIDs.isEmpty
        chosen = Set(childIDs)
        original = childIDs
    }

    func includes(_ childID: UUID) -> Bool {
        isEveryone || chosen.contains(childID)
    }

    /// Ticks or unticks a child. Ticking every current child makes it everyone's again.
    /// - Parameter current: The children that aren't archived.
    mutating func toggle(_ childID: UUID, among current: [UUID]) {
        if isEveryone {
            isEveryone = false
            chosen = Set(current)
        }
        if chosen.contains(childID) {
            chosen.remove(childID)
        } else {
            chosen.insert(childID)
        }
        if !current.isEmpty, Set(current).isSubset(of: chosen) {
            isEveryone = true
            chosen = []
        }
    }

    /// A habit has to be for at least one child.
    func isForAnyone(among current: [UUID]) -> Bool {
        isEveryone || current.contains { chosen.contains($0) }
    }

    /// What to save on the habit: empty for everyone. Archived children it was already for stay on
    /// it, so bringing one back brings the habit back too.
    /// - Parameter current: The children that aren't archived.
    func childIDs(among current: [UUID]) -> [UUID] {
        guard !isEveryone else { return [] }
        let ticked = chosen.filter { current.contains($0) }
        let archived = original.filter { !current.contains($0) }
        return Set(ticked).union(archived).sorted { $0.uuidString < $1.uuidString }
    }

    /// Under the habit's name in Settings: "Leo only", "Maya and Leo", or `nil` for everyone.
    /// - Parameter children: The children that aren't archived, in order.
    static func caption(for habit: Habit, children: [Child]) -> String? {
        guard !habit.childIDs.isEmpty else { return nil }
        let names = children.filter { habit.childIDs.contains($0.id) }.map(\.name)
        switch names.count {
        case 0: return String(localized: "Only archived children")
        case 1: return String(localized: "\(names[0]) only")
        default: return names.formatted(.list(type: .and))
        }
    }
}
