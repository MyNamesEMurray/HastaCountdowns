import SwiftUI
import WidgetKit

@main
struct HastaWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CountdownWidget()
        UpNextWidget()
    }
}
