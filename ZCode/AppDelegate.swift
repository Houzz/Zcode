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
    var castPanel: NSStackView!

    override init() {
        Defaults.register()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @objc func changeCastVisibility(_ sender: NSButton) {
        castPanel.alphaValue = sender.isOn ? 1 : 0
    }

    @IBAction func open(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["swift"]
        castPanel = NSStackView()
        castPanel.orientation = .vertical
        castPanel.alignment = .leading
        castPanel.edgeInsets = NSEdgeInsets(top: 10, left: 40, bottom: 10, right: 20)
        let read = NSButton(checkboxWithTitle: "Generate Cast.read", target: nil, action: nil)
        castPanel.addArrangedSubview(read)
        let coding = NSButton(checkboxWithTitle: "Generate NSCoding", target: nil, action: nil)
        castPanel.addArrangedSubview(coding)
        let copy = NSButton(checkboxWithTitle: "Generate NSCopying", target: nil, action: nil)
        castPanel.addArrangedSubview(copy)
        let customInit = NSButton(checkboxWithTitle: "Generate init(vars...)", target: nil, action: nil)
        castPanel.addArrangedSubview(customInit)

        let leftView = NSStackView()
        leftView.orientation = .vertical
        leftView.alignment = .leading
        leftView.edgeInsets = NSEdgeInsets(top: 10, left: 40, bottom: 10, right: 20)
        let assert = NSButton(checkboxWithTitle: "Assert Outlets", target: nil, action: nil)
        leftView.addArrangedSubview(assert)
        let cast = NSButton(checkboxWithTitle: "Cast", target: self, action: #selector(changeCastVisibility(_:)))
        leftView.addArrangedSubview(cast)
        let defaults = NSButton(checkboxWithTitle: "Defaults", target: nil, action: nil)
        leftView.addArrangedSubview(defaults)

        let stackView = NSStackView()
        stackView.alignment = .top
        stackView.addArrangedSubview(leftView)
        stackView.addArrangedSubview(castPanel)
        castPanel.alphaValue = 0

        openPanel.accessoryView = stackView
        openPanel.isAccessoryViewDisclosed = true
        openPanel.begin { (result) in
            if result == .OK, let doc = openPanel.urls.first {
                var options = CommandOptions.none
                if cast.isOn {
                    options.insert(.cast)
                    if read.isOn {
                        options.insert(.read)
                    }
                    if coding.isOn {
                        options.insert(.coding)
                        if copy.isOn {
                            options.insert(.copying)
                        }
                    }
                    if customInit.isOn {
                        options.insert(.customInit)
                    }
                }
                if assert.isOn {
                    options.insert(.assert)
                }
                if defaults.isOn {
                    options.insert(.defaults)
                }

                do {
                    try self.process(file: doc, with: options)
                    NSDocumentController.shared.noteNewRecentDocumentURL(doc)
                    UserDefaults.standard.set(options.rawValue, forKey: doc.path)
                } catch {
                    let alert = NSAlert()
                    alert.addButton(withTitle: "Ok")
                    alert.messageText = "Error"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    _ = alert.runModal()
                }
            }
        }
    }

    func process(file: URL, with options: CommandOptions) throws {
        guard let source = LinesSource(file: file, completion: {
            let alert = NSAlert()
            alert.addButton(withTitle: "Ok")
            if let error = $0 {
                alert.alertStyle = .warning
                alert.messageText = "Error"
                alert.informativeText = error.localizedDescription
            } else {
                alert.messageText = "Done!"
                alert.informativeText = "File \(file.lastPathComponent) Written"
                alert.alertStyle = .informational
            }
            _ = alert.runModal()
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



