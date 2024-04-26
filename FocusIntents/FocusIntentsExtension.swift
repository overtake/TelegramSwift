//
//  FocusIntentsExtension.swift
//  FocusIntents
//
//  Created by Mikhail Filimonov on 25.04.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import AppIntents
import OSLog


@main
struct FocusIntentsExtension: AppIntentsExtension {
    init() {
        AppDependencyManager.shared.add(dependency: AppIntentsData.shared)
    }
}
