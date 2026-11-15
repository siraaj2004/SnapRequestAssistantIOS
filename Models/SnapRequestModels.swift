import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Manual contact only
// There is deliberately NO surname/initial search field and NO gender field.
// A contact can only be added when you already know that exact person:
// they contacted you first, you are already mutual, or you know them personally.
// Snapchat provides no public API for friend discovery, friend requests,
// chat reading or chat sending, so this app never does any of those things.

enum KnownBasis: String, CaseIterable, Codable, Identifiable {
    case contactedFirst, alreadyMutual, knownPersonally
    var id: String { rawValue }
    var label: String {
        switch self {
        case .contactedFirst: return "They contacted me first"
        case .alreadyMutual: return "Already mutual / accepted"
        case .knownPersonally: return "I already know them personally"
        }
    }
}

enum ContactStage: String, Codable {
    case toReview, requestSentByMe, requestAccepted, declinedOrClosed
    var label: String {
        switch self {
        case .toReview: return "To review in Snapchat"
        case .requestSentByMe: return "Request sent by me in Snapchat"
        case .requestAccepted: return "Request accepted (confirmed by me)"
        case .declinedOrClosed: return "Closed — do not contact again"
        }
    }
}

struct ManualContact: Identifiable, Codable, Equatable {
    var id = UUID()
    var username: String = ""
    var basis: KnownBasis = .contactedFirst
    var adultConfirmed: Bool = false
    var stage: ContactStage = .toReview
    var notes: String = ""

    /// Exact Snapchat usernames only: letters, numbers, underscore, dot, hyphen.
    /// No spaces, no surname-only browsing, no partial-initial search.
    static func isValidUsername(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.count <= 30 else { return false }
        guard !trimmed.contains(" ") else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    var canSave: Bool {
        Self.isValidUsername(username) && adultConfirmed
    }

    /// Official Snapchat profile link for a KNOWN username.
    /// Opening it shows that profile in Snapchat for YOUR manual review.
    /// It does not add, accept, or message anyone by itself.
    var snapchatProfileURL: URL? {
        guard Self.isValidUsername(username) else { return nil }
        return URL(string: "https://www.snapchat.com/add/\(username)")
    }
}

struct ActivityEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var date = Date()
    var text: String = ""
    /// Every history entry exists only because you tapped a confirmation
    /// in this app after doing the step yourself in Snapchat.
    /// The app never creates a "sent" entry on its own.
    var userConfirmed = true
}

enum SessionState: String, Codable {
    case idle, running, paused
    var label: String {
        switch self {
        case .idle: return "Stopped"
        case .running: return "Running — manual checks every 2 hours"
        case .paused: return "Paused"
        }
    }
}

struct FirstMessageDraft: Identifiable {
    var id = UUID()
    var text: String
    static let all: [FirstMessageDraft] = [
        FirstMessageDraft(text: "Hi! How are you?"),
        FirstMessageDraft(text: "Hey! How's your day going?"),
        FirstMessageDraft(text: "Hi! Nice to meet you."),
        FirstMessageDraft(text: "Hello! Hope you're doing well."),
    ]
}

final class SnapRequestStore: ObservableObject {
    @Published var contacts: [ManualContact] = [] { didSet { save() } }
    @Published var history: [ActivityEntry] = [] { didSet { save() } }
    @Published var sessionState: SessionState = .idle { didSet { save() } }
    @Published var sessionStartedAt: Date? { didSet { save() } }
    @Published var nextCheckAt: Date? { didSet { save() } }

    /// The 2-hour cycle, in seconds. This is a manual reminder only.
    static let checkInterval: TimeInterval = 2 * 60 * 60
    static let reminderID = "snap-request-2h-manual-check"

    private let contactsKey = "snap-request-contacts-v1"
    private let historyKey = "snap-request-history-v1"
    private let sessionKey = "snap-request-session-v1"

    init() { load() }

    // MARK: Contacts

    func add(_ contact: ManualContact) {
        guard contact.canSave else { return }
        var saved = contact
        saved.username = saved.username.trimmingCharacters(in: .whitespacesAndNewlines)
        contacts.append(saved)
        log("Added manual contact @\(saved.username) — \(saved.basis.label). Nothing sent.")
    }

    func update(_ contact: ManualContact) {
        guard let i = contacts.firstIndex(where: { $0.id == contact.id }) else { return }
        contacts[i] = contact
    }

    func delete(at offsets: IndexSet) { contacts.remove(atOffsets: offsets) }

    func deleteAll() {
        contacts = []
        history = []
        stopSession()
        log("All local data deleted by you.")
    }

    // MARK: Session — Start / Pause / Stop, every 2 hours, manual only

    func startSession() {
        sessionState = .running
        if sessionStartedAt == nil { sessionStartedAt = Date() }
        nextCheckAt = Date().addingTimeInterval(Self.checkInterval)
        scheduleReminder()
        log("Session started. Next manual check due in 2 hours. No automatic search or sending.")
    }

    func pauseSession() {
        guard sessionState == .running else { return }
        sessionState = .paused
        nextCheckAt = nil
        cancelReminder()
        log("Session paused. 2-hour reminders paused with it.")
    }

    func resumeSession() {
        guard sessionState == .paused else { return }
        sessionState = .running
        nextCheckAt = Date().addingTimeInterval(Self.checkInterval)
        scheduleReminder()
        log("Session resumed. Next manual check due in 2 hours.")
    }

    func stopSession() {
        sessionState = .idle
        sessionStartedAt = nil
        nextCheckAt = nil
        cancelReminder()
        log("Session stopped. 2-hour reminders cancelled.")
    }

    /// One repeating local notification every 2 hours while the session runs.
    /// Tapping it only opens this app. It does not open Snapchat, search,
    /// send a request, or send a message on its own.
    func scheduleReminder() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Snap Request Assistant — manual check due"
            content.body = "Your 2-hour check is due. Open the app, review your list, and do any Snapchat step yourself if you choose to."
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Self.checkInterval, repeats: true)
            let request = UNNotificationRequest(identifier: Self.reminderID, content: content, trigger: trigger)
            center.add(request)
        }
    }

    func cancelReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.reminderID])
    }

    /// Call this only after YOU have done the step in Snapchat yourself.
    func logManualStep(_ text: String) {
        log(text)
    }

    private func log(_ text: String) {
        history.insert(ActivityEntry(date: Date(), text: text, userConfirmed: true), at: 0)
    }

    // MARK: Opening Snapchat — official scheme only, no login in this app

    static func openSnapchat() {
        #if canImport(UIKit)
        if let url = URL(string: "snapchat://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let web = URL(string: "https://www.snapchat.com") {
            UIApplication.shared.open(web)
        }
        #endif
    }

    static func openContactInSnapchat(_ contact: ManualContact) {
        #if canImport(UIKit)
        if let url = contact.snapchatProfileURL {
            UIApplication.shared.open(url)
        }
        #endif
    }

    // MARK: Persistence — on this phone only

    private struct SessionSave: Codable {
        var state: SessionState
        var startedAt: Date?
        var nextCheckAt: Date?
    }

    private func save() {
        if let data = try? JSONEncoder().encode(contacts) {
            UserDefaults.standard.set(data, forKey: contactsKey)
        }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
        let session = SessionSave(state: sessionState, startedAt: sessionStartedAt, nextCheckAt: nextCheckAt)
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: contactsKey),
           let decoded = try? JSONDecoder().decode([ManualContact].self, from: data) {
            contacts = decoded
        }
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([ActivityEntry].self, from: data) {
            history = decoded
        }
        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let decoded = try? JSONDecoder().decode(SessionSave.self, from: data) {
            sessionState = decoded.state
            sessionStartedAt = decoded.startedAt
            nextCheckAt = decoded.nextCheckAt
        }
    }
}
