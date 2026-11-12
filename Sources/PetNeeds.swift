import Foundation

/// Pure, testable pet-needs persistence. Values are always clamped to 0...10.
struct PetNeeds {
    var hunger: Double
    var company: Double

    static let hungerKey = "petNeeds.hunger"
    static let companyKey = "petNeeds.company"
    static let updatedKey = "petNeeds.updatedAt"

    static func clamp(_ value: Double) -> Double {
        value.isFinite ? max(0, min(10, value)) : 10
    }

    func save(to defaults: UserDefaults, now: Date) {
        defaults.set(Self.clamp(hunger), forKey: Self.hungerKey)
        defaults.set(Self.clamp(company), forKey: Self.companyKey)
        defaults.set(now.timeIntervalSince1970, forKey: Self.updatedKey)
    }

    static func restore(from defaults: UserDefaults, now: Date) -> PetNeeds {
        guard defaults.object(forKey: updatedKey) != nil else {
            return PetNeeds(hunger: 10, company: 10)
        }
        let saved = defaults.double(forKey: updatedKey)
        let elapsed = min(3600, max(0, now.timeIntervalSince1970 - saved))
        return PetNeeds(
            hunger: clamp(defaults.double(forKey: hungerKey) - elapsed / 18),
            company: clamp(defaults.double(forKey: companyKey) - elapsed / 22)
        )
    }
}
