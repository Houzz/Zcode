//
//  AppDelegate.swift
//  ZCode
//
//  Created by Guy on 04/11/2017.
//  Copyright © 2017 Houzz. All rights reserved.
//

import Cocoa


@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    override init() {
        Defaults.register()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @IBAction func open(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["swift"]
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.edgeInsets = NSEdgeInsets(top: 10, left: 40, bottom: 10, right: 20)
        let read = NSButton(checkboxWithTitle: "Generate Cast.read", target: nil, action: nil)
        stackView.addArrangedSubview(read)
        let coding = NSButton(checkboxWithTitle: "Generate NSCoding", target: nil, action: nil)
        stackView.addArrangedSubview(coding)
        let copy = NSButton(checkboxWithTitle: "Generate NSCopying", target: nil, action: nil)
        stackView.addArrangedSubview(copy)
        let customInit = NSButton(checkboxWithTitle: "Generate init(vars...)", target: nil, action: nil)
        stackView.addArrangedSubview(customInit)
        openPanel.accessoryView = stackView
        openPanel.begin { (result) in
            if result == .OK, let doc = openPanel.urls.first {
                var options = CommandOptions.cast
                if read.state == .on {
                    options.insert(.read)
                }
                if coding.state == .on {
                    options.insert(.coding)
                    if copy.state == .on {
                        options.insert(.copying)
                    }
                }
                if customInit.state == .on {
                    options.insert(.customInit)
                }

                do {
                    try self.process(file: doc, with: options)
                    NSDocumentController.shared.noteNewRecentDocumentURL(doc)
                    UserDefaults.standard.set(options.rawValue, forKey: doc.path)
                } catch {}
            }
        }
    }

    func process(file: URL, with options: CommandOptions) throws {
        guard let source = LinesSource(file: file, completion: {
            guard $0 == nil else {
                return
            }
            return
        }) else {
            throw CommandError.unknown
        }
        let zcode = SourceZcodeCommand(source: source, options: options)
        zcode.perform()
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let rawOptions = UserDefaults.standard.integer(forKey: filename)
        let options = CommandOptions(rawValue: rawOptions)
        let doc = URL(fileURLWithPath: filename)
        try? process(file: doc, with: options)
        return true
    }
}



