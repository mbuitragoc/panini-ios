import Foundation
import MultipeerConnectivity
import NearbyInteraction
import Observation

// MARK: - NearbySessionManager
//
// Orchestrates MultipeerConnectivity (peer discovery + data exchange) and
// NearbyInteraction (UWB distance measurement) to implement the tap-to-add flow.
//
// Flow:
//  1. start() → MC advertises + browses simultaneously
//  2. Peer found → auto-invite; both sides accept
//  3. MC connects → both sides create NISession, exchange discoveryTokens via MC
//  4. NISession runs → distance reported continuously
//  5. Distance < tapThreshold → send userID payload → peer fires friend request
//  6. onFriendDiscovered?(friendUserID) is called on the main actor

@Observable
@MainActor
final class NearbySessionManager: NSObject {

    // MARK: State

    enum SessionState: Equatable {
        case idle
        case unavailable
        case searching
        case ranging(handle: String, distance: Float)
        case tapDetected(handle: String, friendUserID: String)
    }

    private(set) var sessionState: SessionState = .idle

    var onFriendDiscovered: ((String) -> Void)?

    // MARK: Private

    private let tapThreshold: Float = 0.25  // metres
    private let serviceType  = "panini-frd"  // max 15 chars, MC limit

    private var myUserID = ""
    private var myHandle = ""
    private var profileSent = false

    // MC
    private var mcPeerID: MCPeerID?
    private var mcSession: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    // NI
    private var niSession: NISession?
    private var peerNIToken: NIDiscoveryToken?
    private var peerHandle = ""
    private var peerUserID = ""

    // MARK: - Public API

    func start(userID: String, handle: String) {
        guard NISession.isSupported else {
            sessionState = .unavailable
            return
        }
        guard sessionState == .idle else { return }

        myUserID = userID
        myHandle = handle
        profileSent = false

        let peer = MCPeerID(displayName: handle)
        mcPeerID = peer

        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        mcSession = session

        let adv = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil, serviceType: serviceType)
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv

        let brw = MCNearbyServiceBrowser(peer: peer, serviceType: serviceType)
        brw.delegate = self
        brw.startBrowsingForPeers()
        browser = brw

        sessionState = .searching
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        mcSession?.disconnect()
        niSession?.invalidate()

        advertiser = nil
        browser   = nil
        mcSession  = nil
        niSession  = nil
        mcPeerID   = nil
        peerNIToken = nil
        profileSent = false
        peerHandle  = ""
        peerUserID  = ""

        sessionState = .idle
    }

    // MARK: - NI lifecycle

    private func beginNISession() {
        let ni = NISession()
        ni.delegate = self
        niSession = ni

        guard let token = ni.discoveryToken else { return }
        sendNIToken(token)
    }

    private func sendNIToken(_ token: NIDiscoveryToken) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true),
              let session = mcSession,
              let peer = session.connectedPeers.first
        else { return }

        var payload = Data("NI:".utf8)
        payload.append(data)
        try? session.send(payload, toPeers: [peer], with: .reliable)
    }

    private func sendProfile() {
        guard !profileSent,
              let session = mcSession,
              let peer = session.connectedPeers.first
        else { return }

        profileSent = true
        let payload = Data("UID:\(myUserID):\(myHandle)".utf8)
        try? session.send(payload, toPeers: [peer], with: .reliable)
    }

    private func runNISession() {
        guard let ni = niSession, let token = peerNIToken else { return }
        let config = NINearbyPeerConfiguration(peerToken: token)
        ni.run(config)
    }

    // MARK: - Incoming data

    private func handleData(_ data: Data, from peer: MCPeerID) {
        guard let str = String(data: data, encoding: .utf8) else { return }

        if str.hasPrefix("NI:") {
            let tokenData = data.dropFirst(3)
            if let token = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: NIDiscoveryToken.self, from: tokenData
            ) {
                peerNIToken = token
                runNISession()
            }
        } else if str.hasPrefix("UID:") {
            // Format: UID:<userID>:<handle>
            let body = String(str.dropFirst(4))
            let parts = body.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return }
            peerUserID = parts[0]
            peerHandle = parts[1]

            // Fire friend request and surface tap state
            onFriendDiscovered?(peerUserID)
            sessionState = .tapDetected(handle: peerHandle, friendUserID: peerUserID)
        }
    }
}

// MARK: - MCSessionDelegate

extension NearbySessionManager: MCSessionDelegate {

    nonisolated func session(
        _ session: MCSession,
        peer peerID: MCPeerID,
        didChange state: MCSessionState
    ) {
        Task { @MainActor in
            switch state {
            case .connected:
                self.beginNISession()
            case .notConnected:
                self.niSession?.invalidate()
                self.niSession = nil
                self.peerNIToken = nil
                self.profileSent = false
                if case .tapDetected = self.sessionState { /* keep success state */ } else {
                    self.sessionState = .searching
                }
            default:
                break
            }
        }
    }

    nonisolated func session(
        _ session: MCSession,
        didReceive data: Data,
        fromPeer peerID: MCPeerID
    ) {
        Task { @MainActor in self.handleData(data, from: peerID) }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream,
                             withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession,
                             didStartReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession,
                             didFinishReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID, at localURL: URL?,
                             withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension NearbySessionManager: MCNearbyServiceAdvertiserDelegate {

    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        Task { @MainActor in invitationHandler(true, self.mcSession) }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension NearbySessionManager: MCNearbyServiceBrowserDelegate {

    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        Task { @MainActor in
            guard let session = self.mcSession else { return }
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

// MARK: - NISessionDelegate

extension NearbySessionManager: NISessionDelegate {

    nonisolated func session(
        _ session: NISession,
        didUpdate nearbyObjects: [NINearbyObject]
    ) {
        guard let obj = nearbyObjects.first, let dist = obj.distance else { return }
        Task { @MainActor in
            // Update ranging state
            if case .tapDetected = self.sessionState { return }
            self.sessionState = .ranging(handle: self.peerHandle.isEmpty
                ? self.mcSession?.connectedPeers.first?.displayName ?? ""
                : self.peerHandle, distance: dist)

            // Trigger exchange when close enough
            if dist < self.tapThreshold {
                self.sendProfile()
            }
        }
    }

    nonisolated func session(
        _ session: NISession,
        didRemove nearbyObjects: [NINearbyObject],
        reason: NINearbyObject.RemovalReason
    ) {
        Task { @MainActor in
            if case .tapDetected = self.sessionState { return }
            self.sessionState = .searching
        }
    }

    nonisolated func sessionSuspensionEnded(_ session: NISession) {
        Task { @MainActor in
            if let token = self.peerNIToken {
                session.run(NINearbyPeerConfiguration(peerToken: token))
            }
        }
    }

    nonisolated func session(_ session: NISession, didInvalidateWith error: Error) {}
    nonisolated func sessionWasSuspended(_ session: NISession) {}
}
