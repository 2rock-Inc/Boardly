//
//  PreferenceOptionsTests.swift
//  BoardlyTests
//
//  Locks the PLANKA-pref raw value ↔ label mapping so the row's displayed value
//  and the value PATCHed can't silently diverge.
//

import SwiftUI
import Testing
@testable import Boardly

@Suite("Preference option enums")
struct PreferenceOptionsTests {
    @Test("home view maps raw values to labels")
    func homeView() {
        #expect(HomeViewOption.from("groupedProjects") == .grouped)
        #expect(HomeViewOption.from("gridProjects") == .grid)
        #expect(HomeViewOption.grouped.label == "Groupée")
        #expect(HomeViewOption.grid.label == "Grille")
    }

    @Test("editor mode maps raw values to labels")
    func editorMode() {
        #expect(EditorModeOption.from("wysiwyg") == .wysiwyg)
        #expect(EditorModeOption.from("markup") == .markup)
        #expect(EditorModeOption.markup.label == "Markdown")
    }

    @Test("unknown or nil raw value falls back to the PLANKA default")
    func fallback() {
        #expect(HomeViewOption.from(nil) == .grouped)
        #expect(HomeViewOption.from("weird") == .grouped)
        #expect(EditorModeOption.from(nil) == .wysiwyg)
    }

    @Test("app theme maps to color schemes")
    func appTheme() {
        #expect(AppTheme.system.colorScheme == nil)
        #expect(AppTheme.light.colorScheme == .light)
        #expect(AppTheme.dark.colorScheme == .dark)
        #expect(AppTheme.system.label == "Automatique")
    }
}
