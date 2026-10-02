import WidgetKit
import SwiftUI

@main
struct SuperDashboardWidgetBundle: WidgetBundle {
    var body: some Widget {
        SuperDashboardWidget()
        SuperDashboardWidgetLiveActivity()
        QuickCopyLiveActivity()
    }
}
