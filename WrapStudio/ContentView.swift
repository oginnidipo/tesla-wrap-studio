import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            CarPicker()
                .navigationDestination(for: Car.self) { car in
                    CanvasView(car: car)
                }
        }
        .tint(StudioStyle.accent)
    }
}

#Preview { ContentView() }
