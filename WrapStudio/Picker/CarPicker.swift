import SwiftUI

struct CarPicker: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("WRAP STUDIO", systemImage: "paintpalette.fill")
                        .font(.caption.weight(.heavy)).tracking(2).foregroundStyle(StudioStyle.accent)
                    Text("Your Tesla.\nYour signature.")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Turn a blank canvas into something unmistakably you.")
                        .font(.body).foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("CHOOSE YOUR CANVAS").font(.caption.weight(.bold)).tracking(1.5)
                        Spacer()
                        Text("3 vehicles").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(Car.allCases) { car in
                        NavigationLink(value: car) { CarCard(car: car) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Design a \(car.name) wrap. \(car.templateNote).")
                    }
                }

                Label("Made for imagination. Saved on your device.", systemImage: "lock.shield")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("For your Tesla’s on-screen vehicle visualization. Match the template to your vehicle before exporting.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(22)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
    }
}
