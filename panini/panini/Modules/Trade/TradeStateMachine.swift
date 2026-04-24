import Foundation

// MARK: - TradeStatus

enum TradeStatus: String {
    case proposed
    case accepted
    case declined
    case proposerConfirmed = "proposer_confirmed"
    case completed
}

// MARK: - TradeEvent

enum TradeEvent {
    case accept
    case decline
    case confirm
}

// MARK: - TradeStateMachineError

enum TradeStateMachineError: Error, Equatable {
    case invalidTransition
    case wrongActor
}

// MARK: - TradeStateMachine

/// Pure stateless state machine — no network or persistence dependencies.
/// Mirrors the Go server-side TradeStateMachine for client-side validation.
struct TradeStateMachine {

    /// Returns the next status after applying `event` from the given `actorID`.
    /// Throws `TradeStateMachineError` if the transition is not permitted.
    static func transition(
        current: TradeStatus,
        event: TradeEvent,
        actorID: String,
        proposerID: String,
        recipientID: String
    ) throws -> TradeStatus {
        // Terminal states reject all events.
        guard current != .completed && current != .declined else {
            throw TradeStateMachineError.invalidTransition
        }

        switch current {
        case .proposed:
            switch event {
            case .accept:
                guard actorID == recipientID else { throw TradeStateMachineError.wrongActor }
                return .accepted
            case .decline:
                guard actorID == recipientID else { throw TradeStateMachineError.wrongActor }
                return .declined
            case .confirm:
                throw TradeStateMachineError.invalidTransition
            }

        case .accepted:
            switch event {
            case .confirm:
                guard actorID == proposerID else { throw TradeStateMachineError.wrongActor }
                return .proposerConfirmed
            case .accept, .decline:
                throw TradeStateMachineError.invalidTransition
            }

        case .proposerConfirmed:
            switch event {
            case .confirm:
                guard actorID == recipientID else { throw TradeStateMachineError.wrongActor }
                return .completed
            case .accept, .decline:
                throw TradeStateMachineError.invalidTransition
            }

        case .completed, .declined:
            throw TradeStateMachineError.invalidTransition
        }
    }
}
