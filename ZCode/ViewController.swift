//
//  ViewController.swift
//  ZCode
//
//  Created by Guy on 04/11/2017.
//  Copyright © 2017 Houzz. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    @IBOutlet var useLogger: NSButtonCell!
    @IBOutlet var nilStrings: NSButtonCell!
    @IBOutlet var upperCase: NSButtonCell!
    @IBOutlet var saveButton: NSButtonCell!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        useLogger.state = Defaults.useLogger ?  .on : .off
        nilStrings.state = Defaults.nilEmptyStrings ? .on : .off
        upperCase.state = Defaults.keyCase == .upper ? .on : .off
        saveButton.keyEquivalent = "\r"
        saveButton.isEnabled = false
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func save(_ sender: Any) {
        Defaults.useLogger = useLogger.state == .on
        Defaults.nilEmptyStrings = nilStrings.state == .on
        if upperCase.state == .on {
        Defaults.keyCase = .upper
        }
        saveButton.isEnabled = false
    }

    @IBAction func enableSave(_ sender: NSButton) {
        if (useLogger.state == .on) == Defaults.useLogger &&
            (nilStrings.state == .on) == Defaults.nilEmptyStrings &&
            (Defaults.keyCase == .upper) == (upperCase.state == .on) {
            saveButton.isEnabled = false
        } else {
        saveButton.isEnabled = true
        }
    }
}

