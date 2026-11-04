import SwiftUI

struct CarCard: View {
    let car: Car
    @ScaledMetric(relativeTo: .title) private var cardHeight = 172

    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 8) {
                Text(car.name).font(.title2.bold())
                Text(car.templateNote).font(.caption).foregroundStyle(.white.opacity(0.7))
                Spacer(minLength: 12)
                Label("Start designing", systemImage: "arrow.up.right")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.vertical, 22).padding(.leading, 22)
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(uiImage: UIImage(named: car.carImage) ?? UIImage())
                .resizable().scaledToFill()
                .frame(width: 170, height: cardHeight)
                .clipped().accessibilityHidden(true)
        }
        .frame(minHeight: cardHeight)
        .foregroundStyle(.white)
        .background(Color(white: 0.075))
        .clipShape(.rect(cornerRadius: 22))
    }
}
