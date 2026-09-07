import Foundation

@main
@MainActor
enum InteractiveArtTests {
    static func main() {
        let breath = BreathStore()
        breath.resize(capacity: 2)
        for duration in [1.0, 2.0, 3.0] {
            breath.begin(at: 100)
            breath.end(at: 100 + duration)
        }
        precondition(breath.durations == [2, 3])
        breath.begin(at: 100)
        breath.cancel()
        breath.end(at: 110)
        precondition(breath.durations == [2, 3])
        precondition(BreathStore.widthFraction(for: 6) > BreathStore.widthFraction(for: 2))
        breath.discard()
        precondition(breath.durations.isEmpty && breath.beganAt == nil)

        let suite = "omg-interactive-art-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let sceneA = UUID(), sceneB = UUID()
        let date = Date(timeIntervalSince1970: 1_000_000)
        let plant = DormancyStore(defaults: defaults, at: date)
        let seed = plant.record.seed
        plant.setVisible(true, scene: sceneA, at: date)
        precondition(plant.seconds(at: date.addingTimeInterval(600)) == 600)
        plant.observe(scene: sceneA, at: date.addingTimeInterval(600))
        precondition(plant.isObserving)
        precondition(plant.seconds(at: date.addingTimeInterval(600.5)) == 300)
        precondition(plant.seconds(at: date.addingTimeInterval(601)) == 0)
        precondition(plant.seconds(at: date.addingTimeInterval(602)) == 0 && plant.isObserving)
        plant.leave(at: date.addingTimeInterval(602))
        precondition(!plant.isObserving && plant.seconds(at: date.addingTimeInterval(662)) == 60)

        let monthLater = date.addingTimeInterval(DormancyStore.maximumSeconds + 1000)
        precondition(plant.seconds(at: monthLater) == DormancyStore.maximumSeconds)
        plant.observe(scene: sceneA, at: monthLater)
        plant.setVisible(true, scene: sceneB, at: monthLater)
        plant.setVisible(false, scene: sceneA, at: monthLater.addingTimeInterval(1))
        // A second visible window does not multiply the observation rate.
        precondition(plant.seconds(at: monthLater.addingTimeInterval(2)) == DormancyStore.maximumSeconds - 1200)
        plant.setVisible(false, scene: sceneB, at: monthLater.addingTimeInterval(2))
        precondition(plant.seconds(at: monthLater.addingTimeInterval(100)) == DormancyStore.maximumSeconds - 1200)
        let reopenedPlant = DormancyStore(defaults: defaults, at: monthLater.addingTimeInterval(200))
        precondition(reopenedPlant.isObserving && reopenedPlant.record.seed == seed)
        precondition(reopenedPlant.seconds(at: monthLater.addingTimeInterval(250)) == DormancyStore.maximumSeconds - 1200)
        reopenedPlant.setVisible(true, scene: sceneA, at: monthLater.addingTimeInterval(300))
        precondition(reopenedPlant.seconds(at: monthLater.addingTimeInterval(301)) == DormancyStore.maximumSeconds - 1800)
        reopenedPlant.leave(at: monthLater.addingTimeInterval(301))
        precondition(reopenedPlant.seconds(at: monthLater.addingTimeInterval(311)) == DormancyStore.maximumSeconds - 1790)
        let lockedRelaunch = DormancyStore(defaults: defaults, at: monthLater.addingTimeInterval(400))
        precondition(!lockedRelaunch.isObserving)
        precondition(lockedRelaunch.seconds(at: monthLater.addingTimeInterval(400)) == DormancyStore.maximumSeconds - 1701)
        precondition(DormancyStore.growth(for: 0) == 0 && DormancyStore.growth(for: DormancyStore.maximumSeconds) == 1)
        precondition(DormancyStore.growth(for: DormancyStore.maximumSeconds * 2) == 1)

        let legacySuite = suite + "-legacy"
        let legacyDefaults = UserDefaults(suiteName: legacySuite)!
        defer { legacyDefaults.removePersistentDomain(forName: legacySuite) }
        struct Legacy: Codable { let restSeconds: Double; let restingSince: Date; let seed: UInt64 }
        legacyDefaults.set(try! JSONEncoder().encode(Legacy(restSeconds: 300, restingSince: date, seed: 42)),
                           forKey: "originalMotivationGenerator.v1.dormancy")
        let migrated = DormancyStore(defaults: legacyDefaults, at: date.addingTimeInterval(100))
        precondition(migrated.seconds(at: date.addingTimeInterval(100)) == 400 && migrated.record.seed == 42)
        migrated.observe(scene: sceneA, at: date.addingTimeInterval(100))
        precondition(!migrated.isObserving) // An offscreen neighboring view cannot unlock it.

        let application = ApplicationStore()
        precondition(!application.submit(at: date))
        application.applicant = "某个人"
        application.reason = " \n "
        precondition(!application.canSubmit)
        application.reason = "我想进去看看"
        precondition(application.submit(at: date, delay: 3))
        precondition(!application.submit(at: date, delay: 100))
        application.advance(at: date.addingTimeInterval(2))
        application.enter()
        precondition(application.stage == .waiting)
        // Returning after the deadline also resolves a review that was offscreen or suspended.
        application.advance(at: date.addingTimeInterval(60))
        precondition(application.stage == .approved)
        application.enter()
        precondition(application.stage == .entered)
        application.startAgain()
        precondition(application.stage == .editing && application.applicant.isEmpty && application.reason.isEmpty)
        application.applicant = "下一位"
        application.reason = "重新申请"
        application.submit(at: date, delay: 5)
        application.startAgain()
        application.advance(at: date.addingTimeInterval(100))
        precondition(application.stage == .editing && application.approvalDate == nil)
        print("PASS: breath overflow/cancel/discard, locked garden growth/600x rewind/caps/relaunch/migration/windows, application validation/review/reset")
    }
}
