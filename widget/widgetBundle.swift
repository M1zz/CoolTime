//
//  widgetBundle.swift
//  CoolTime Widget
//
//  Created by Leeo on 12/1/25.
//

import WidgetKit
import SwiftUI

@main
struct CoolTimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        CoolTimeWidget()
        CoolTimeAccessoryWidget()
    }
}
