import XCTest
@testable import SnapRequestAssistant

final class SnapRequestAssistantTests: XCTestCase {
    func testValidUsername() {
        XCTAssertTrue(ManualContact.isValidUsername("siraaj2209"))
        XCTAssertFalse(ManualContact.isValidUsername("Shaik Syed"))
        XCTAssertFalse(ManualContact.isValidUsername("ab"))
        XCTAssertFalse(ManualContact.isValidUsername("Shaik"))
        // A bare surname is not treated as a valid contact by itself:
        // canSave still needs adult confirmation AND a known basis,
        // and the app provides no search to turn a surname into a list.
    }

    func testCannotSaveWithoutAdultConfirmation() {
        let contact = ManualContact(username: "siraaj2209", basis: .knownPersonally, adultConfirmed: false)
        XCTAssertFalse(contact.canSave)
        let confirmed = ManualContact(username: "siraaj2209", basis: .knownPersonally, adultConfirmed: true)
        XCTAssertTrue(confirmed.canSave)
    }

    func testFirstMessageDraftsAreExactlyTheApprovedList() {
        XCTAssertEqual(FirstMessageDraft.all.map { $0.text }, [
            "Hi! How are you?",
            "Hey! How's your day going?",
            "Hi! Nice to meet you.",
            "Hello! Hope you're doing well.",
        ])
    }

    func testTwoHourInterval() {
        XCTAssertEqual(SnapRequestStore.checkInterval, 7200, accuracy: 0.001)
    }

    func testStoreDoesNotAutoSendOnAdd() {
        let store = SnapRequestStore()
        let before = store.history.count
        store.add(ManualContact(username: "siraaj2209", basis: .knownPersonally, adultConfirmed: true))
        // Adding only logs the add itself. It does not create a "request sent" entry
        // for Snapchat, because no request was sent.
        XCTAssertFalse(store.history.contains(where: { $0.text.contains("Request to @siraaj2209 confirmed sent") }))
        XCTAssertGreaterThanOrEqual(store.history.count, before)
    }

    func testProfileURLUsesKnownUsernameOnly() {
        let contact = ManualContact(username: "siraaj2209", basis: .knownPersonally, adultConfirmed: true)
        XCTAssertEqual(contact.snapchatProfileURL?.absoluteString, "https://www.snapchat.com/add/siraaj2209")
        let bad = ManualContact(username: "Shaik Syed", basis: .knownPersonally, adultConfirmed: true)
        XCTAssertNil(bad.snapchatProfileURL)
    }
}
