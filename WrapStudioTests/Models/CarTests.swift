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
}
