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
        upperCase.state = Defaults.upperCase ? .on : .off
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
        Defaults.upperCase = upperCase.state == .on
        saveButton.isEnabled = false
    }

    @IBAction func enableSave(_ sender: NSButton) {
        if (useLogger.state == .on) == Defaults.useLogger &&
            (nilStrings.state == .on) == Defaults.nilEmptyStrings &&
            Defaults.upperCase == (upperCase.state == .on) {
            saveButton.isEnabled = false
        } else {
        saveButton.isEnabled = true
        }
    }
}

