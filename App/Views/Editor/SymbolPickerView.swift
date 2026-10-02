import SwiftUI

struct SymbolPickerView: View {
    @Binding var selection: String
    let tint: Color
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private let columns = [GridItem(.adaptive(minimum: 48), spacing: 8)]

    private var filteredCategories: [SymbolCategory] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return SymbolCategory.all }
        return SymbolCategory.all.compactMap { category in
            let matches = category.symbols.filter { $0.replacingOccurrences(of: ".", with: " ").contains(trimmed) }
            return matches.isEmpty ? nil : SymbolCategory(name: category.name, symbols: matches)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20, pinnedViews: []) {
                ForEach(filteredCategories) { category in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(category.name)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(category.symbols, id: \.self) { symbol in
                                Button {
                                    selection = symbol
                                    dismiss()
                                } label: {
                                    Image(systemName: symbol)
                                        .font(.system(size: 21, weight: .medium))
                                        .foregroundStyle(selection == symbol ? .white : .primary)
                                        .frame(width: 48, height: 48)
                                        .background(
                                            selection == symbol ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground)),
                                            in: .rect(cornerRadius: 12, style: .continuous)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(symbol.replacingOccurrences(of: ".", with: " "))
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Symbol")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search Symbols")
        .overlay {
            if filteredCategories.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }
}

struct SymbolCategory: Identifiable {
    let name: String
    let symbols: [String]

    var id: String { name }

    static let all: [SymbolCategory] = [
        SymbolCategory(name: "Celebrations", symbols: [
            "star.fill", "heart.fill", "sparkles", "party.popper.fill", "birthday.cake.fill", "gift.fill",
            "balloon.fill", "balloon.2.fill", "fireworks", "crown.fill", "wand.and.stars", "bubbles.and.sparkles.fill",
            "wineglass.fill", "suit.heart.fill", "heart.circle.fill", "heart.text.square.fill", "star.circle.fill", "teddybear.fill",
            "heart.square.fill", "star.square.fill",
        ]),
        SymbolCategory(name: "Travel", symbols: [
            "airplane", "airplane.departure", "airplane.arrival", "airplane.circle.fill", "car.fill", "bus.fill",
            "tram.fill", "train.side.front.car", "cablecar.fill", "ferry.fill", "sailboat.fill", "bicycle",
            "scooter", "fuelpump.fill", "suitcase.fill", "suitcase.rolling.fill", "map.fill", "mappin.and.ellipse",
            "location.fill", "globe.americas.fill", "globe.europe.africa.fill", "globe.asia.australia.fill", "bed.double.fill", "building.columns.fill",
            "signpost.right.fill", "binoculars.fill", "beach.umbrella.fill", "tent.fill", "mountain.2.fill", "camera.fill",
            "car.side.fill", "truck.box.fill", "bolt.car.fill", "house.lodge.fill",
        ]),
        SymbolCategory(name: "Seasons & Nature", symbols: [
            "sun.max.fill", "sun.horizon.fill", "sunrise.fill", "sunset.fill", "moon.fill", "moon.stars.fill",
            "cloud.sun.fill", "umbrella.fill", "snowflake", "flame.fill", "drop.fill", "rainbow",
            "leaf.fill", "tree.fill", "camera.macro", "carrot.fill", "water.waves", "bolt.fill",
            "pawprint.fill", "dog.fill", "cat.fill", "bird.fill", "fish.fill", "hare.fill",
            "tortoise.fill", "ladybug.fill", "cloud.rain.fill", "cloud.snow.fill", "wind", "thermometer.sun.fill",
            "tree.circle.fill",
        ]),
        SymbolCategory(name: "Sports & Fitness", symbols: [
            "figure.run", "figure.walk", "figure.hiking", "figure.outdoor.cycle", "figure.pool.swim", "figure.yoga",
            "figure.strengthtraining.traditional", "figure.dance", "figure.skiing.downhill", "figure.snowboarding", "figure.surfing", "figure.climbing",
            "figure.soccer", "figure.basketball", "figure.american.football", "figure.tennis", "figure.golf", "figure.hockey",
            "figure.skating", "figure.fishing", "dumbbell.fill", "sportscourt.fill", "soccerball", "basketball.fill",
            "football.fill", "baseball.fill", "tennis.racket", "volleyball.fill", "hockey.puck.fill", "trophy.fill",
            "medal.fill", "flag.checkered", "stopwatch.fill", "laurel.leading", "figure.archery", "figure.bowling",
            "figure.boxing", "figure.equestrian.sports", "figure.martial.arts", "figure.rower", "figure.badminton", "figure.volleyball",
        ]),
        SymbolCategory(name: "Entertainment", symbols: [
            "music.note", "music.mic", "music.note.list", "music.quarternote.3", "guitars.fill", "pianokeys",
            "theatermasks.fill", "ticket.fill", "film.fill", "popcorn.fill", "tv.fill", "gamecontroller.fill",
            "headphones", "photo.fill", "paintpalette.fill", "paintbrush.fill", "book.fill", "books.vertical.fill",
        ]),
        SymbolCategory(name: "Food & Drink", symbols: [
            "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill", "frying.pan.fill", "basket.fill", "cart.fill",
            "fork.knife.circle.fill", "mug.fill", "waterbottle.fill",
        ]),
        SymbolCategory(name: "Life & Milestones", symbols: [
            "person.2.fill", "person.3.fill", "figure.2.and.child.holdinghands", "figure.and.child.holdinghands", "stroller.fill", "figure.wave",
            "hand.wave.fill", "hand.thumbsup.fill", "hands.sparkles.fill", "face.smiling", "graduationcap.fill", "studentdesk",
            "pencil", "briefcase.fill", "building.2.fill", "building.fill", "house.fill", "key.fill",
            "sofa.fill", "shippingbox.fill", "trophy.circle.fill", "rosette", "checkmark.seal.fill", "flag.fill",
        ]),
        SymbolCategory(name: "Health", symbols: [
            "cross.case.fill", "stethoscope", "pills.fill", "bandage.fill", "brain.head.profile", "heart.circle.fill",
        ]),
        SymbolCategory(name: "Everyday", symbols: [
            "calendar", "clock.fill", "hourglass", "alarm.fill", "timer", "bell.fill",
            "envelope.fill", "phone.fill", "paperplane.fill", "lightbulb.fill", "dollarsign.circle.fill", "creditcard.fill",
            "bag.fill", "tshirt.fill", "eyeglasses", "scissors", "hammer.fill", "wrench.and.screwdriver.fill",
            "laptopcomputer", "iphone", "desktopcomputer", "globe", "atom", "lock.fill",
            "pencil.and.ruler.fill", "backpack.fill", "puzzlepiece.fill", "dice.fill", "megaphone.fill", "flag.2.crossed.fill",
            "gift.circle.fill", "storefront.fill",
        ]),
    ]
}
