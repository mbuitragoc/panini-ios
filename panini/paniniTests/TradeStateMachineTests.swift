import XCTest
@testable import panini

final class TradeStateMachineTests: XCTestCase {

    private let proposer  = "user-proposer"
    private let recipient = "user-recipient"
    private let bystander = "user-bystander"

    // MARK: - Valid transitions

    func test_proposedAccept_byRecipient_returnsAccepted() throws {
        let next = try TradeStateMachine.transition(
            current: .proposed, event: .accept,
            actorID: recipient, proposerID: proposer, recipientID: recipient
        )
        XCTAssertEqual(next, .accepted)
    }

    func test_proposedDecline_byRecipient_returnsDeclined() throws {
        let next = try TradeStateMachine.transition(
            current: .proposed, event: .decline,
            actorID: recipient, proposerID: proposer, recipientID: recipient
        )
        XCTAssertEqual(next, .declined)
    }

    func test_acceptedConfirm_byProposer_returnsProposerConfirmed() throws {
        let next = try TradeStateMachine.transition(
            current: .accepted, event: .confirm,
            actorID: proposer, proposerID: proposer, recipientID: recipient
        )
        XCTAssertEqual(next, .proposerConfirmed)
    }

    func test_proposerConfirmedConfirm_byRecipient_returnsCompleted() throws {
        let next = try TradeStateMachine.transition(
            current: .proposerConfirmed, event: .confirm,
            actorID: recipient, proposerID: proposer, recipientID: recipient
        )
        XCTAssertEqual(next, .completed)
    }

    // MARK: - Invalid transitions (wrong event for status)

    func test_proposedConfirm_throwsInvalidTransition() {
        XCTAssertThrowsError(try TradeStateMachine.transition(
            current: .proposed, event: .confirm,
            actorID: recipient, proposerID: proposer, recipientID: recipient
        )) { error in
            XCTAssertEqual(error as? TradeStateMachineError, .invalidTransition)
        }
    }

    func test_acceptedAccept_throwsInvalidTransition() {
        XCTAssertThrowsError(try TradeStateMachine.transition(
            current: .accepted, event: .accept,
            actorID: recipient, proposerID: proposer, recipientID: recipient
        )) { error in
            XCTAssertEqual(error as? TradeStateMachineError, .invalidTransition)
        }
    }

    func test_acceptedDecline_throwsInvalidTransition() {
        XCTAssertThrowsError(try TradeStateMachine.transition(
            current: .accepted, event: .decline,
            actorID: recipient, proposerID: proposer, recipientID: recipient
        )) { error in
            XCTAssertEqual(error as? TradeStateMachineError, .invalidTransition)
        }
    }

    func test_proposerConfirmedAccept_throwsInvalidTransition() {
        XCTAssertThrowsError(try TradeStateMachine.transition(
            current: .proposerConfirmed, event: .accept,
            actorID: recipient, proposerID: proposer, recipientID: recipient
        )) { error in
            XCTAssertEqual(error as? TradeStateMachineError, .invalidTransition)
        }
    }

    func test_proposerConfirmedDecline_throwsInvalidTransition() {
        XCTAssertThrowsError(try TradeStateMachine.transition(
            current: .proposerConfirmed, event: .decline,
            actorID: recipient, proposerID: proposer, recipientID: recipient
        )) { error in
            XCTAssertEqual(error as? TradeStateMachineError, .invalidTransition)
        }
    }

    // MARK: - Wrong actor

    func test_proposedAccept_byProposer_throwsWrongActor() {
        XCTAssertThrowsError(try TradeStateMachine.transition(
            current: .proposed, event: .accept,
            actorID: proposer, proposerID: proposer, recipientID: recipient
        )) { error in
            XCTAssertEqual(error as? TradeStateMachineError, .wrongActor)
        }
    }

    func test_proposedDecline_byProposer_throwsWrongActor() {
        XCTAssertThrowsError(try TradeStateMachine.transition(
            current: .proposed, event: .decline,
            actorID: proposer, proposerID: proposer, recipientID: recipient
        )) { error in
            XCTAssertEqual(error as? TradeStateMachineError, .wrongActor)
        }
    }

    func test_proposedAccept_byBystander_throwsWrongActor() {
        XCTAssertThrowsError(try TradeStateMachine.transition(
            current: .proposed, event: .accept,
            actorID: bystander, proposerID: proposer, recipientID: recipient
        )) { error in
            XCTAssertEqual(error as? TradeStateMachineError, .wrongActor)
        }
    }

    func test_acceptedConfirm_byRecipient_throwsWrongActor() {
        XCTAssertThrowsError(try TradeStateMachine.transition(
            current: .accepted, event: .confirm,
            actorID: recipient, proposerID: proposer, recipientID: recipient
        )) { error in
            XCTAssertEqual(error as? TradeStateMachineError, .wrongActor)
        }
    }

    func test_acceptedConfirm_byBystander_throwsWrongActor() {
        XCTAssertThrowsError(try TradeStateMachine.transition(
            current: .accepted, event: .confirm,
            actorID: bystander, proposerID: proposer, recipientID: recipient
        )) { error in
            XCTAssertEqual(error as? TradeStateMachineError, .wrongActor)
        }
    }

    func test_proposerConfirmedConfirm_byProposer_throwsWrongActor() {
        XCTAssertThrowsError(try TradeStateMachine.transition(
            current: .proposerConfirmed, event: .confirm,
            actorID: proposer, proposerID: proposer, recipientID: recipient
        )) { error in
            XCTAssertEqual(error as? TradeStateMachineError, .wrongActor)
        }
    }

    // MARK: - Terminal states reject all events

    func test_completedRejectsAllEvents() {
        let events: [TradeEvent] = [.accept, .decline, .confirm]
        let actors = [proposer, recipient, bystander]
        for event in events {
            for actor in actors {
                XCTAssertThrowsError(try TradeStateMachine.transition(
                    current: .completed, event: event,
                    actorID: actor, proposerID: proposer, recipientID: recipient
                ), "\(event) by \(actor) on completed") { error in
                    XCTAssertEqual(error as? TradeStateMachineError, .invalidTransition)
                }
            }
        }
    }

    func test_declinedRejectsAllEvents() {
        let events: [TradeEvent] = [.accept, .decline, .confirm]
        let actors = [proposer, recipient, bystander]
        for event in events {
            for actor in actors {
                XCTAssertThrowsError(try TradeStateMachine.transition(
                    current: .declined, event: event,
                    actorID: actor, proposerID: proposer, recipientID: recipient
                ), "\(event) by \(actor) on declined") { error in
                    XCTAssertEqual(error as? TradeStateMachineError, .invalidTransition)
                }
            }
        }
    }

    // MARK: - TradeStatus raw values

    func test_tradeStatusRawValues() {
        XCTAssertEqual(TradeStatus.proposed.rawValue,          "proposed")
        XCTAssertEqual(TradeStatus.accepted.rawValue,          "accepted")
        XCTAssertEqual(TradeStatus.declined.rawValue,          "declined")
        XCTAssertEqual(TradeStatus.proposerConfirmed.rawValue, "proposer_confirmed")
        XCTAssertEqual(TradeStatus.completed.rawValue,         "completed")
        XCTAssertNil(TradeStatus(rawValue: "unknown"))
    }
}
