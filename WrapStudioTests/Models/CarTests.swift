import Testing
import UIKit
@testable import Tesla_Car_Wrap

struct CarTests {
    @Test(arguments: Car.allCases)
    @MainActor func eachVehicleLoadsItsOwnArtwork(car: Car) throws {
        #expect(car.template == "\(car.rawValue)-template")
        let template = try #require(UIImage(named: car.template))
        #expect(template.size == car.templateSize)
        #expect(UIImage(named: car.carImage) != nil)
        #expect(UIImage(named: car.maskImage)?.size == car.templateSize)
        #expect(UIImage(named: car.overlayImage)?.size == car.templateSize)
    }

    @Test func savedRawValuesNeverChange() {
        // Saved designs store these; renaming one would orphan every design that uses it.
        #expect(Car.m3.rawValue == "m3")
        #expect(Car.my.rawValue == "my")
        #expect(Car.ct.rawValue == "ct")
        #expect(Car(rawValue: "m3-2024") == .m3Refresh)
        #expect(Car(rawValue: "my-2025") == .myRefresh)
    }

    @Test func everyVehicleBelongsToExactlyOneFamily() {
        let listed = VehicleFamily.allCases.flatMap(\.cars)
        #expect(listed.count == Car.allCases.count)
        #expect(Set(listed) == Set(Car.allCases))
        #expect(VehicleFamily.model3.heroCar == .m3Refresh)
        #expect(VehicleFamily.modelY.cars.count == 5)
    }

    @Test func onlyOriginalVehiclesHavePrototypeDrafts() {
        #expect(Car.allCases.filter { $0.legacyFileName != nil } == [.m3, .my, .ct])
        #expect(Car.ct.legacyFileName == "Cybertruck")
    }

    @Test func mirrorAxesReflectPointsAndRotations() {
        let vertical = MirrorAxis.vertical(sum: 1024)
        #expect(vertical.mirror(CGPoint(x: 100, y: 300)) == CGPoint(x: 924, y: 300))
        #expect(vertical.mirroredRotation(0.5) == -0.5)
        let horizontal = MirrorAxis.horizontal(sum: 768)
        #expect(horizontal.mirror(CGPoint(x: 100, y: 300)) == CGPoint(x: 100, y: 468))
        #expect(abs(horizontal.mirroredRotation(0.5) - (.pi - 0.5)) < 1e-9)
        #expect(Car.ct.mirrorAxis.isVertical == false)
        #expect(Car.allCases.filter { $0 != .ct }.allSatisfy { $0.mirrorAxis.isVertical })
    }
}
