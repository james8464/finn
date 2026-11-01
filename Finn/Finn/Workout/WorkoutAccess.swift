import Foundation
import Observation
import StoreKit

/// Without Finn Coach+, one free workout every two weeks; with it, as many as the person likes.
/// A workout is a session: the sets after its first one, and Try again, never count again.
nonisolated struct FreeWorkoutRule: Equatable, Sendable {
    /// the days from one free workout to the next
    static let interval = 14

    /// when the last free workout began; nil before the first one
    var lastFreeWorkout: Date?

    /// when the next free workout opens; nil before the first one, which is free at once
    func nextFreeWorkout(calendar: Calendar = .current) -> Date? {
        lastFreeWorkout.flatMap { calendar.date(byAdding: .day, value: Self.interval, to: $0) }
    }

    func allowsFreeWorkout(at date: Date, calendar: Calendar = .current) -> Bool {
        guard let next = nextFreeWorkout(calendar: calendar) else { return true }
        return date >= next
    }
}

/// what the workout model asks before a new workout begins
protocol WorkoutStartGate: AnyObject {
    /// whether a new workout may begin at `date`. May ask the App Store again before saying no
    func allowsNewWorkout(at date: Date) async -> Bool
    /// a new workout's first set was measured at `date`
    func workoutBegan(at date: Date)
}

/// Finn Coach+ from the App Store, and the free workout for everyone else. It follows the
/// subscription as it renews, lapses or is refunded, wherever it was bought
@Observable
final class WorkoutAccess: WorkoutStartGate {
    /// an active Finn Coach+ subscription on this Apple Account
    private(set) var isSubscribed = false
    private(set) var rule: FreeWorkoutRule
    /// off for demo input and tests, which start as many workouts as they need
    @ObservationIgnored let limitsFreeWorkouts: Bool
    @ObservationIgnored private let preferences: FinnPreferences
    @ObservationIgnored private var updates: Task<Void, Never>?
    #if DEBUG
    /// `-finn-ui-demo-purchase` stands for a purchase the App Store never sees
    @ObservationIgnored private var demoSubscribed = false
    #endif

    init(preferences: FinnPreferences, limitsFreeWorkouts: Bool) {
        self.preferences = preferences
        self.limitsFreeWorkouts = limitsFreeWorkouts
        rule = FreeWorkoutRule(lastFreeWorkout: preferences.lastFreeWorkout)
    }

    /// when the next free workout opens; nil while one is free
    var nextFreeWorkout: Date? {
        rule.allowsFreeWorkout(at: .now) ? nil : rule.nextFreeWorkout()
    }

    /// reads the subscription, then follows the App Store's updates for as long as the app runs:
    /// renewals, refunds, Ask to Buy, and purchases made on another device
    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            await self?.refresh()
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish() }
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            // the app sells one thing: any of its subscriptions is Finn Coach+
            if case .verified(let transaction) = entitlement,
               transaction.productType == .autoRenewable, transaction.revocationDate == nil {
                active = true
            }
        }
        #if DEBUG
        active = active || demoSubscribed
        #endif
        isSubscribed = active
    }

    /// right after a purchase on the plan offer, before the App Store's update arrives
    func purchased() async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-finn-ui-demo-purchase") { demoSubscribed = true }
        #endif
        await refresh()
    }

    func allowsNewWorkout(at date: Date) async -> Bool {
        guard limitsFreeWorkouts, !isSubscribed, !rule.allowsFreeWorkout(at: date) else { return true }
        // a renewal or a purchase elsewhere may not have reached the app yet
        await refresh()
        return isSubscribed
    }

    func workoutBegan(at date: Date) {
        guard limitsFreeWorkouts, !isSubscribed else { return }
        rule.lastFreeWorkout = date
        preferences.lastFreeWorkout = date
    }
}
