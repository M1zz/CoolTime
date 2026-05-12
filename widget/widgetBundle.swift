import WidgetKit
import SwiftUI

@main
struct CoolTimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        CoolTimeWidget()
        ResistanceWidget()
        CoolTimeAccessoryWidget()
    }
}
