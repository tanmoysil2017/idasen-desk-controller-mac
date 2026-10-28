//
//  PreferencesWindowController.swift
//  Desk Controller
//
//  Created by David Williames on 11/1/21.
//

import Cocoa
import ServiceManagement

class PreferencesWindowController: NSWindowController {
    
    @IBOutlet weak var standingHeightField: NSTextField!
    @IBOutlet weak var sittingHeightField: NSTextField!
    
    @IBOutlet weak var unitsPopUpButton: NSPopUpButton!
    @IBOutlet weak var currentHeightField: NSTextField?
    
    @IBOutlet weak var autoStandEnabledCheckbox: NSButton!
    @IBOutlet weak var autoStandIntervalStepper: NSStepper!
    @IBOutlet weak var autoStandIntervalLabel: NSTextField!
    @IBOutlet weak var autoStandInactiveStepper: NSStepper!
    @IBOutlet weak var autoStandInactiveLabel: NSTextField!
    
    @IBOutlet weak var openAtLoginCheckbox: NSButton!
    
    static let sharedInstance = PreferencesWindowController(windowNibName: "PreferencesWindowController")
    
    var deskController: DeskController? {
        didSet {
            deskPosition = deskController?.desk.position
        }
    }
    
    var deskPosition: Float? {
        didSet {
            currentHeightField?.isEnabled = (deskPosition != nil)
            
            var offsetPosition = Preferences.shared.positionOffset + (deskPosition ?? 0)
            if !Preferences.shared.isMetric {
                offsetPosition = offsetPosition.convertToInches()
            }
            currentHeightField?.stringValue = String(format: "%.1f", offsetPosition)
        }
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        updateOpenAtLogin()
        NotificationCenter.default.addObserver(
            self, selector: #selector(updateOpenAtLogin),
            name: NSApplication.didBecomeActiveNotification, object: nil)
        
        unitsPopUpButton.selectItem(at: Preferences.shared.isMetric ? 0 : 1)
        
        autoStandEnabledCheckbox.state = Preferences.shared.automaticStandEnabled ? .on : .off
        autoStandIntervalStepper.intValue = Int32(Preferences.shared.automaticStandPerHour / 60)
        autoStandInactiveStepper.intValue = Int32(Preferences.shared.automaticStandInactivity / 60)
        
        updateLabels()
        
        deskController?.onPositionChange({ [weak self] position in
            self?.deskPosition = position
        })
    }
    
    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        updateOpenAtLogin()
        AppDelegate.bringToFront(window: self.window!)
    }
    
    func updateLabels() {
        
        var standingPosition = Preferences.shared.standingPosition
        var sittingPosition = Preferences.shared.sittingPosition
        
        if !Preferences.shared.isMetric {
            standingPosition = standingPosition.convertToInches()
            sittingPosition = sittingPosition.convertToInches()
        }
        
        standingHeightField.stringValue = String(format: "%.1f", standingPosition)
        sittingHeightField.stringValue = String(format: "%.1f", sittingPosition)
        
        autoStandIntervalLabel.stringValue = String(format: "%.f",
            Preferences.shared.automaticStandPerHour / 60)
        autoStandInactiveLabel.stringValue = String(format: "%.f",
            Preferences.shared.automaticStandInactivity / 60)

        let autoEnabled = Preferences.shared.automaticStandEnabled
        autoStandInactiveLabel.textColor = autoEnabled ? .labelColor : .disabledControlTextColor
        autoStandIntervalLabel.textColor = autoEnabled ? .labelColor : .disabledControlTextColor
        autoStandIntervalStepper.isEnabled = autoEnabled
        autoStandInactiveStepper.isEnabled = autoEnabled
        
        var offsetPosition = Preferences.shared.positionOffset + (deskPosition ?? 0)
        if !Preferences.shared.isMetric {
            offsetPosition = offsetPosition.convertToInches()
        }
        
        currentHeightField?.stringValue = String(format: "%.1f", offsetPosition)
    }
    
    @IBAction func changeStandingHeightField(_ sender: NSTextField) {
        
        if var newPosition = Float(standingHeightField.stringValue) {
            if !Preferences.shared.isMetric {
                newPosition = newPosition.convertToCentimeters()
            }
            Preferences.shared.standingPosition = newPosition
        }
        
    }
    
    @IBAction func changedSittingHeightField(_ sender: NSTextField) {
        
        if var newPosition = Float(sittingHeightField.stringValue) {
            if !Preferences.shared.isMetric {
                newPosition = newPosition.convertToCentimeters()
            }
            Preferences.shared.sittingPosition = newPosition
        }
    }
    
    @IBAction func changedCurrentHeightField(_ sender: NSTextField) {
        
        if var newPosition = Float(sender.stringValue), let deskPosition = deskPosition {
            if !Preferences.shared.isMetric {
                newPosition = newPosition.convertToCentimeters()
            }
            let offset = newPosition - deskPosition
            Preferences.shared.positionOffset = offset
        }
    }
    
    @IBAction func toggledAutoStandCheckbox(_ sender: NSButton) {
        Preferences.shared.automaticStandEnabled = sender.state == .on
        updateLabels()
    }
    
    @IBAction func changedAutoStandStepper(_ sender: NSStepper) {
        let newInterval = Double(autoStandIntervalStepper.intValue)
        Preferences.shared.automaticStandPerHour = newInterval * 60
        updateLabels()
    }
    
    @IBAction func changedAutoStandInactiveStepper(_ sender: NSStepper) {
        let newInactive = Double(autoStandInactiveStepper.intValue)
        Preferences.shared.automaticStandInactivity = newInactive * 60
        updateLabels()
    }
    
    @IBAction func changedUnitsPopUpButton(_ sender: NSPopUpButton) {
        Preferences.shared.isMetric = sender.titleOfSelectedItem == "cm"
        updateLabels()
    }
    
    @objc private func updateOpenAtLogin() {
        openAtLoginCheckbox.title = "Open Desk Controller at login"
        openAtLoginCheckbox.isEnabled = true
        openAtLoginCheckbox.toolTip = nil
        switch Preferences.shared.openAtLoginStatus {
        case .enabled:
            openAtLoginCheckbox.state = .on
        case .requiresApproval:
            openAtLoginCheckbox.state = .mixed
            openAtLoginCheckbox.title = "Open at login (pending)"
            openAtLoginCheckbox.toolTip = "Approve Desk Controller in Login Items Settings."
        case .notRegistered:
            openAtLoginCheckbox.state = .off
        case .notFound:
            openAtLoginCheckbox.state = .off
            openAtLoginCheckbox.isEnabled = false
            openAtLoginCheckbox.toolTip = "Install Desk Controller in Applications, then reopen it."
        @unknown default:
            openAtLoginCheckbox.state = .off
            openAtLoginCheckbox.isEnabled = false
        }
    }

    @IBAction func toggledOpenAtLoginCheckbox(_ sender: NSButton) {
        let status = Preferences.shared.openAtLoginStatus
        do {
            try Preferences.shared.setOpenAtLogin(status != .enabled && status != .requiresApproval)
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Could not change Open at Login"
            alert.beginSheetModal(for: window!)
        }
        updateOpenAtLogin()
    }

    @IBAction func openLoginItemsSettings(_ sender: Any) {
        SMAppService.openSystemSettingsLoginItems()
    }
    
    
}
