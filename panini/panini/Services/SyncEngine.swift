import Foundation
import Observation
import SwiftData

/// Observable service that orchestrates background sync with the remote API.
@Observable
final class SyncEngine {
    /// True while a sync operation is in progress.
    private(set) var isSyncing: Bool = false

    /// Performs a full sync against the remote API.
    ///
    /// - Parameter context: The SwiftData `ModelContext` used for persistence.
    ///
    /// Stub implementation — real sync logic delivered in the sync feature slice.
    func sync(context: ModelContext) async {
        isSyncing = true
        defer { isSyncing = false }
        // TODO: implement in sync slice
    }
}
