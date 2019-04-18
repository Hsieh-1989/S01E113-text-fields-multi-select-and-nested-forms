//
//  ViewController.swift
//  FormsSample
//
//  Created by Chris Eidhof on 22.03.18.
//  Copyright © 2018 objc.io. All rights reserved.
//

import UIKit

enum ShowPreview {
    case always
    case never
    case whenUnlocked
    
    static let all: [ShowPreview] = [.always, .whenUnlocked, .never]
    
    var text: String {
        switch self {
        case .always: return "Always"
        case .whenUnlocked: return "When Unlocked"
        case .never: return "Never"
        }
    }
}
struct Hotspot {
    var isEnabled: Bool = true
    var password: String = "hello"
    var networkName: String = "my network"
    var showPreview: ShowPreview = .always
}

struct Settings {
    var hotspot = Hotspot()
    
    var hotspotEnabled: String {
        return hotspot.isEnabled ? "On" : "Off"
    }
}

extension Hotspot {
    var enabledSectionTitle: String? {
        return isEnabled ? "Personal Hotspot Enabled" : nil
    }
}

let showPreviewForm: Form<Hotspot> = [
    .section(
        ShowPreview.all.map { option in
            .optionCell(title: option.text, option: option, keyPath: \.showPreview)
        }
    )
]

let settingsForm: Form<Settings> = [
    .section([
        .detailTextCell(title: "Personal Hotspot", keyPath: \.hotspotEnabled, form: hotspotForm.pullback(keyPath: \.hotspot))
    ])
]

let hotspotForm: Form<Hotspot> = [
    .section([
        .controlCell(title: "Personal Hotspot", control: .uiSwitch(keyPath: \.isEnabled))
    ], footer: \.enabledSectionTitle),
    .section([
        .detailTextCell(title: "Notification", keyPath: \.showPreview.text, form: showPreviewForm)
    ]),
    .section([
        .nestedTextField(title: "Password", keyPath: \.password),
        .nestedTextField(title: "Network Name", keyPath: \.networkName)
    ])
]
