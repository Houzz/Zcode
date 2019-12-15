//
//  AppDelegate.swift
//  ZCode
//
//  Created by Guy on 04/11/2017.
//  Copyright © 2017 Houzz. All rights reserved.
//

import Cocoa
import GitHubUpdates

private func isXcodeRunning() -> Bool {
    return !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dt.Xcode").isEmpty
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, GitHubUpdaterDelegate {
    var castPanel: NSStackView!
    let updater = GitHubUpdater()

    override init() {
        Defaults.register()
    }
    
    func updater(_ updater: GitHubUpdater, version v1: GitHubVersion, isNewerThanVersion v2: GitHubVersion) -> Bool {
        var va1 = [0,0,0]
        var va2 = [0,0,0]
        for (idx,n) in v1.versionString.components(separatedBy: ".").enumerated() {
            if idx < 3 {
                va1[idx] = Int(n) ?? 0
            }
        }
        for (idx,n) in v2.versionString.components(separatedBy: ".").enumerated() {
            if idx < 3 {
                va2[idx] = Int(n) ?? 0
            }
        }
        let v1int = va1[0] * 1000000 + va1[1] * 1000 + va1[2]
        let v2int = va2[0] * 1000000 + va2[1] * 1000 + va2[2]

        return v1int > v2int
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        updater.user = "houzz"
        updater.repository = "zcode"
        updater.delegate = self
        updater.checkForUpdatesInBackground()
    }

    @IBAction func checkForUpdates(_ sender: Any) {
        updater.checkForUpdates(sender)
    }
    
    func interceptInstallCompletion(_ done: @escaping () -> Void) {
        guard isXcodeRunning() else {
            done();
            return;
        }
        let alert = NSAlert()
        alert.addButton(withTitle: "Continue")
        alert.messageText = "Quit Xcode"
        alert.informativeText = "Xcode can't be running while updating Zcode. Please quit it."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            interceptInstallCompletion(done)

        default:
            return
        }
    }

    @discardableResult private func appUpdate() -> Bool {
        if let latest = checkForUpdate() {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.addButton(withTitle: "Update")
                alert.messageText = "Version \(latest.version.display) Available"
                let currentVerionString = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "?"
                alert.informativeText = "You have version \(currentVerionString). Please update"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Cancel")
                if alert.runModal() == .alertFirstButtonReturn, let link = URL(string: latest.htmlUrl) {
                    NSWorkspace.shared.open(link)
                }
            }
            return true
        }
        return false
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    @objc func changeCastVisibility(_ sender: NSButton) {
        castPanel.alphaValue = sender.isOn ? 1 : 0
    }

    @IBAction func open(_ sender: Any) {
        if appUpdate() {
            return
        }
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
        let codable = NSButton(checkboxWithTitle: "Codable", target: nil, action: nil)
        leftView.addArrangedSubview(codable)

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
                if codable.isOn {
                    options.insert(.codable)
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



