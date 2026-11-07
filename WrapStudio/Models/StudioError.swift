import Foundation

enum StudioError: LocalizedError {
    case unsupportedDesign, unreadableImage, missingArtwork, pngEncoding, oversizedExport, designNotFound, emptyText

    var errorDescription: String? {
        switch self {
        case .unsupportedDesign: "This design was saved by a newer version of Tesla Car Wrap."
        case .unreadableImage: "This photo could not be opened. Please choose another image."
        case .missingArtwork: "The vehicle artwork could not be loaded."
        case .pngEncoding: "The PNG could not be created. Please try again."
        case .oversizedExport: "This PNG exceeds Tesla’s 1 MB limit. Try using fewer photo stickers."
        case .designNotFound: "This design no longer exists."
        case .emptyText: "Type something to turn into a sticker."
        }
    }
}
