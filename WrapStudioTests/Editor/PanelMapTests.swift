import Testing
import UIKit
@testable import Tesla_Car_Wrap

@MainActor struct PanelMapTests {
    @Test(arguments: [(Car.m3, 16), (.my, 16), (.ct, 27), (.m3Refresh, 17), (.myRefresh, 18), (.mxRefresh, 19)])
    func findsEachBodyPanel(car: Car, panels: Int) throws {
        let map = try #require(PanelMap.forCar(car))
        #expect(map.width == Int(car.templateSize.width))
        #expect(map.height == Int(car.templateSize.height))
        #expect(map.panelCount == panels)
    }

    @Test func snapsTapsOnOutlinesToTheNearestPanel() throws {
        let map = try #require(PanelMap.forCar(.m3))
        let hood = try #require(map.panel(at: CGPoint(x: 512, y: 260)))
        #expect(map.panel(at: CGPoint(x: 512, y: 560)) == nil, "Glass roof")
        #expect(map.panel(at: CGPoint(x: -4, y: 10)) == nil)
        // Walk up from inside the hood until leaving it, then check the snap.
        var y: CGFloat = 260
        while map.panel(at: CGPoint(x: 512, y: y), tolerance: 0) == hood { y -= 1 }
        #expect(map.panel(at: CGPoint(x: 512, y: y - 2), tolerance: 6) == hood)
        let anchor = map.anchor(for: hood, near: CGPoint(x: 512, y: y - 2))
        #expect(map.panel(at: anchor, tolerance: 0) == hood)
    }

    @Test(arguments: Car.allCases)
    func panelsHaveMirrorTwins(car: Car) throws {
        let map = try #require(PanelMap.forCar(car))
        var checked = 0, matched = 0
        for y in stride(from: 8, to: map.height, by: 24) {
            for x in stride(from: 8, to: map.width, by: 24) {
                let point = CGPoint(x: x, y: y)
                guard map.panel(at: point, tolerance: 0) != nil else { continue }
                checked += 1
                if map.panel(at: car.mirrorAxis.mirror(point), tolerance: 12) != nil { matched += 1 }
            }
        }
        #expect(checked > 100)
        #expect(Double(matched) / Double(checked) > 0.93, "\(car): \(matched)/\(checked)")
    }

    @Test func fillImageColoursOnlyTheChosenPanel() throws {
        let map = try #require(PanelMap.forCar(.m3))
        let hood = try #require(map.panel(at: CGPoint(x: 512, y: 260)))
        let image = try #require(map.image(colors: [hood: "F14B35"]))
        let pixels = try TestArtwork.pixels(UIImage(cgImage: image))
        #expect(TestArtwork.isCoral(TestArtwork.pixel(pixels, width: 1024, x: 512, y: 260)))
        #expect(TestArtwork.pixel(pixels, width: 1024, x: 140, y: 480)[3] == 0)
        #expect(TestArtwork.pixel(pixels, width: 1024, x: 512, y: 560)[3] == 0)
    }

    @Test(arguments: Car.allCases)
    func stickerHomeIsInsideAPanel(car: Car) throws {
        let home = try #require(PanelMap.forCar(car)?.stickerHome)
        #expect(PanelMap.forCar(car)?.panel(at: home.center, tolerance: 0) != nil)
        #expect(home.size.width > 60 && home.size.height > 60)
    }
}
