import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @EnvironmentObject private var store: SnapRequestStore

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
            ContactsView()
                .tabItem { Label("Contacts", systemImage: "person.crop.circle") }
            MessagesView()
                .tabItem { Label("Messages", systemImage: "message") }
            LimitsView()
                .tabItem { Label("Limits", systemImage: "exclamationmark.shield") }
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: SnapRequestStore
    @State private var now = Date()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Snap Request Assistant")
                        .font(.largeTitle).bold()
                    Text("Manual only. This app never logs into Snapchat, never searches for strangers, and never sends a request or message by itself. Every Snapchat step is done by you, inside Snapchat.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    GroupBox("Session — every 2 hours, manual reminder only") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Status: \(store.sessionState.label)").bold()
                            if let next = store.nextCheckAt, store.sessionState == .running {
                                Text("Next manual check: \(next, style: .date) \(next, style: .time)")
                                Text("Time left: \(timeLeft(to: next))")
                                    .font(.subheadline).foregroundColor(.secondary)
                            } else if store.sessionState == .paused {
                                Text("Paused — no reminders will fire until you resume.")
                            } else {
                                Text("Stopped — tap Start to begin a 2-hour reminder cycle.")
                            }
                            Text("When a reminder fires, it only opens this app. It does not search Snapchat or send anything. You decide each step, in Snapchat, yourself.")
                                .font(.caption).foregroundColor(.secondary)
                            HStack {
                                Button("Start") { store.startSession() }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(store.sessionState == .running)
                                if store.sessionState == .paused {
                                    Button("Resume") { store.resumeSession() }
                                        .buttonStyle(.bordered)
                                } else {
                                    Button("Pause") { store.pauseSession() }
                                        .buttonStyle(.bordered)
                                        .disabled(store.sessionState != .running)
                                }
                                Button("Stop") { store.stopSession() }
                                    .buttonStyle(.bordered)
                                    .disabled(store.sessionState == .idle)
                            }
                            Button("Do a manual check now") {
                                store.logManualStep("Manual check opened by you. No automatic action taken.")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Button("Open Snapchat") {
                        SnapRequestStore.openSnapchat()
                        store.logManualStep("Opened Snapchat from this app (official app / website only). No request sent by this app.")
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                    GroupBox("Activity history — you-confirmed steps only") {
                        if store.history.isEmpty {
                            Text("No activity yet. History only appears when you confirm a step you did yourself.")
                                .font(.subheadline).foregroundColor(.secondary)
                        } else {
                            ForEach(store.history.prefix(50)) { entry in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.text).font(.subheadline)
                                    Text(entry.date, style: .date) + Text(" ") + Text(entry.date, style: .time)
                                }
                                .font(.caption).foregroundColor(.secondary)
                                Divider()
                            }
                        }
                    }

                    Button("Delete all local data", role: .destructive) {
                        store.deleteAll()
                    }
                }
                .padding()
            }
            .navigationTitle("Home")
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { value in
                now = value
            }
        }
    }

    private func timeLeft(to date: Date) -> String {
        let remaining = max(0, date.timeIntervalSince(now))
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

struct ContactsView: View {
    @EnvironmentObject private var store: SnapRequestStore
    @State private var showingAdd = false

    var body: some View {
        NavigationView {
            List {
                Section("What goes here — and what does not") {
                    Text("Add only an exact username for a person you already know. There is no field to search by surname or initial, and no gender filter — Snapchat does not provide a reliable one, and this app will not guess from a username or photo.")
                        .font(.subheadline)
                }
                Section("Manual contacts (\(store.contacts.count))") {
                    if store.contacts.isEmpty {
                        Text("Empty. Add a manual contact to begin — nothing is searched or added automatically.")
                    }
                    ForEach(store.contacts) { contact in
                        NavigationLink(destination: ContactDetailView(contact: contact)) {
                            VStack(alignment: .leading) {
                                Text("@\(contact.username)").bold()
                                Text(contact.stage.label).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: store.delete)
                }
            }
            .navigationTitle("Contacts")
            .toolbar {
                Button("Add") { showingAdd = true }
            }
            .sheet(isPresented: $showingAdd) {
                AddContactView()
            }
        }
    }
}

struct AddContactView: View {
    @EnvironmentObject private var store: SnapRequestStore
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var basis: KnownBasis = .contactedFirst
    @State private var adultConfirmed = false
    @State private var notes = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Exact username you already know") {
                    TextField("Snapchat username, e.g. siraaj2209", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    Text("Type the full, exact username. Do not type a surname or initial to browse strangers — this app has no search for that, on purpose.")
                        .font(.caption).foregroundColor(.secondary)
                }
                Section("How do you know them?") {
                    Picker("Basis", selection: $basis) {
                        ForEach(KnownBasis.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                }
                Section("Confirmation required") {
                    Toggle("Adult status confirmed by me", isOn: $adultConfirmed)
                    Text("Save stays disabled until you confirm this and the username is valid. This is your confirmation, not a check by the app.")
                        .font(.caption).foregroundColor(.secondary)
                }
                Section("Private note (optional, on this phone only)") {
                    TextField("Note", text: $notes)
                }
                Button("Save manual contact") {
                    var contact = ManualContact(username: username, basis: basis, adultConfirmed: adultConfirmed, notes: notes)
                    contact.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.add(contact)
                    dismiss()
                }
                .disabled(!ManualContact(username: username, basis: basis, adultConfirmed: adultConfirmed).canSave)
            }
            .navigationTitle("Add manual contact")
            .toolbar {
                Button("Cancel") { dismiss() }
            }
        }
    }
}

struct ContactDetailView: View {
    @EnvironmentObject private var store: SnapRequestStore
    @State var contact: ManualContact
    @State private var showRequestConfirm = false
    @State private var showAcceptedConfirm = false

    var body: some View {
        Form {
            Section("Profile to review — in Snapchat, by you") {
                Text("@\(contact.username)").font(.title3).bold()
                Text(contact.basis.label)
                Text(contact.stage.label).foregroundColor(.secondary)
                if !contact.notes.isEmpty { Text(contact.notes) }
            }
            Section("Step 1 — Review, in Snapchat") {
                Button("Open this profile in Snapchat") {
                    SnapRequestStore.openContactInSnapchat(contact)
                    store.logManualStep("Opened @\(contact.username) in Snapchat for manual review. No request sent by this app.")
                }
                Text("Review the profile in Snapchat yourself. If it is not the right person, close it and mark this contact Closed below. This app cannot verify identity for you.")
                    .font(.caption).foregroundColor(.secondary)
            }
            Section("Step 2 — Request confirmation (you, in Snapchat)") {
                Text("This app has no button that sends a Snapchat request. If you choose to send one, tap Add in Snapchat yourself, then come back and confirm here so history is honest.")
                    .font(.caption).foregroundColor(.secondary)
                Button("I sent the request myself in Snapchat") { showRequestConfirm = true }
                    .disabled(contact.stage != .toReview)
                Button("Mark as Closed — do not contact again") {
                    contact.stage = .declinedOrClosed
                    store.update(contact)
                    store.logManualStep("Closed @\(contact.username) — marked do not contact again.")
                }
            }
            Section("Step 3 — Acceptance confirmation (you, in Snapchat)") {
                Button("I confirmed in Snapchat that the request was accepted") { showAcceptedConfirm = true }
                    .disabled(contact.stage != .requestSentByMe)
            }
        }
        .navigationTitle("@\(contact.username)")
        .alert("Confirm you sent it yourself?", isPresented: $showRequestConfirm) {
            Button("Yes, I sent it in Snapchat") {
                contact.stage = .requestSentByMe
                store.update(contact)
                store.logManualStep("Request to @\(contact.username) confirmed sent by you in Snapchat.")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only tap Yes if you actually tapped Add in Snapchat yourself. This app did not send anything.")
        }
        .alert("Confirm acceptance?", isPresented: $showAcceptedConfirm) {
            Button("Yes, I saw the acceptance in Snapchat") {
                contact.stage = .requestAccepted
                store.update(contact)
                store.logManualStep("Request to @\(contact.username) confirmed accepted in Snapchat. Message drafts are now available.")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Only tap Yes if you saw the acceptance in Snapchat yourself.")
        }
    }
}

struct MessagesView: View {
    @EnvironmentObject private var store: SnapRequestStore
    @State private var copiedText: String? = nil

    private var acceptedContacts: [ManualContact] {
        store.contacts.filter { $0.stage == .requestAccepted }
    }

    var body: some View {
        NavigationView {
            List {
                Section("First-message drafts — copy, review, send yourself") {
                    Text("Drafts appear only for contacts you marked as accepted in Snapchat. Tap Copy, paste it in Snapchat, edit it if you want, and send it yourself. This app never sends a message.")
                        .font(.subheadline)
                    if acceptedContacts.isEmpty {
                        Text("No accepted contacts yet. No drafts are shown until you confirm an acceptance in Snapchat.")
                    } else {
                        ForEach(acceptedContacts) { contact in
                            Text("@\(contact.username)").bold()
                        }
                    }
                }
                Section("Suggestions") {
                    ForEach(FirstMessageDraft.all) { draft in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(draft.text)
                            HStack {
                                Button("Copy") {
                                    #if canImport(UIKit)
                                    UIPasteboard.general.string = draft.text
                                    #endif
                                    copiedText = draft.text
                                }
                                .buttonStyle(.bordered)
                                Button("I sent this myself in Snapchat") {
                                    store.logManualStep("First message confirmed sent by you in Snapchat (draft copied from this app). Text: \(draft.text)")
                                }
                                .buttonStyle(.bordered)
                            }
                            if copiedText == draft.text {
                                Text("Copied — paste it in Snapchat and review before you send.").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Messages")
        }
    }
}

struct LimitsView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("What this app cannot do — honestly").font(.title3).bold()
                    Text("Snapchat does not provide a public API for friend discovery, friend requests, chat reading, or chat sending. So this app cannot do those things, and it does not fake them:")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• No search by surname, initial, or username to find strangers.")
                        Text("• No gender filter — no reliable Snapchat gender data, and no guessing from a username or photo.")
                        Text("• No Snapchat password, login, or session in this app.")
                        Text("• No scraping of private profiles, no bypass of CAPTCHA, rate limits, or privacy controls.")
                        Text("• No bulk or unsolicited requests, and no automatic sending.")
                        Text("• No fake success: history only logs steps you confirm you did in Snapchat.")
                    }
                    Text("What the 2-hour cycle actually is").font(.title3).bold()
                    Text("Start begins a repeating local notification every 2 hours. Pause stops the reminders. Stop ends the session and cancels them. The notification only opens this app so you can do a manual check if you choose to. It does not run Snapchat in the background, and iOS would not allow this app to do Snapchat actions in the background anyway.")
                    Text("Install note").font(.title3).bold()
                    Text("This is an unsigned build from GitHub Actions. Install it from Windows with Sideloadly or AltStore, which sign it with your own Apple ID. It is not an App Store build, and it expires on the usual free-signing cycle (about 7 days) unless you re-sign it.")
                }
                .padding()
            }
            .navigationTitle("Limits")
        }
    }
}
