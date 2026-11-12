import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

let suite = "TouchBarPET.PetNeedsTests.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let now = Date(timeIntervalSince1970: 2_000_000)
let initial = PetNeeds.restore(from: defaults, now: now)
check(initial.hunger == 10 && initial.company == 10, "new pet starts full")
PetNeeds(hunger: 8, company: 6).save(to: defaults, now: now)
let later = PetNeeds.restore(from: defaults, now: now.addingTimeInterval(18))
check(abs(later.hunger - 7) < 0.00001, "hunger decays offline")
check(abs(later.company - (6 - 18.0 / 22.0)) < 0.00001, "company decays offline")
let backward = PetNeeds.restore(from: defaults, now: now.addingTimeInterval(-100))
check(backward.hunger == 8 && backward.company == 6, "clock rollback does not restore needs")
let capped = PetNeeds.restore(from: defaults, now: now.addingTimeInterval(100_000))
check(capped.hunger == 0 && capped.company == 0, "offline decay bounded and clamped")
PetNeeds(hunger: 50, company: -3).save(to: defaults, now: now)
let clamped = PetNeeds.restore(from: defaults, now: now)
check(clamped.hunger == 10 && clamped.company == 0, "saved values are clamped")
print("PetNeeds tests passed")
