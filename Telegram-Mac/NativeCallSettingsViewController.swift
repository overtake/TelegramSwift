//
//  NativeCallSettingsViewController.swift
//  Telegram
//
//  Created by keepcoder on 17/05/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

class NativeCallSettingsViewController: NSViewController {
    @IBOutlet weak var inputDeviceTitle: NSTextField!
    @IBOutlet weak var outputDeviceTitle: NSTextField!
    @IBOutlet weak var inputDeviceButton: NSPopUpButton!
    @IBOutlet weak var outputDeviceButton: NSPopUpButton!
    @IBOutlet weak var okButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!
    
    @IBAction func saveAction(_ sender: Any) {
        onSave(inputDevices[inputDeviceButton.index(of: inputDeviceButton.selectedItem!)], outputDevices[outputDeviceButton.index(of: outputDeviceButton.selectedItem!)])
        if let window = view.window {
            window.sheetParent?.endSheet(window)
        }
    }
    @IBAction func cancelAction(_ sender: Any) {
        onCancel()
        if let window = view.window {
            window.sheetParent?.endSheet(window)
        }
    }
    
    private let inputDevices:[AudioDevice]
    private let outputDevices:[AudioDevice]
    private let currentInputDeviceId:String
    private let currentOutputDeviceId:String
    private let onSave:(AudioDevice, AudioDevice)->Void
    private let onCancel:()->Void
    
    init(inputDevices:[AudioDevice], outputDevices:[AudioDevice], currentInputDeviceId:String, currentOutputDeviceId:String, onSave:@escaping(AudioDevice, AudioDevice)->Void, onCancel:@escaping()->Void) {
        self.inputDevices = inputDevices
        self.outputDevices = outputDevices
        self.currentInputDeviceId = currentInputDeviceId
        self.currentOutputDeviceId = currentOutputDeviceId
        self.onSave = onSave
        self.onCancel = onCancel
        super.init(nibName: NSNib.Name(rawValue: "NativeCallSettingsViewController"), bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        for device in inputDevices {
//            let index = inputDeviceButton.itemArray.count
//            
//            inputDeviceButton.addItem(withTitle: device.deviceId == "default" ? tr(L10n.callDeviceSettingsDefault) : device.deviceName)
//            if inputDevices[index].deviceId == currentInputDeviceId {
//                inputDeviceButton.select(inputDeviceButton.lastItem)
//            }
//        }
//        for device in outputDevices {
//            let index = outputDeviceButton.itemArray.count
//            outputDeviceButton.addItem(withTitle:  device.deviceId == "default" ? tr(L10n.callDeviceSettingsDefault) : device.deviceName)
//            if outputDevices[index].deviceId == currentOutputDeviceId {
//                outputDeviceButton.select(outputDeviceButton.lastItem)
//            }
//        }
//        
//        inputDeviceTitle.stringValue = tr(L10n.callDeviceSettingsInputLabel)
//        outputDeviceTitle.stringValue = tr(L10n.callDeviceSettingsOutputLabel)
        
        okButton.title = tr(L10n.modalOK)
        cancelButton.title = tr(L10n.modalCancel)
    }
    
}
