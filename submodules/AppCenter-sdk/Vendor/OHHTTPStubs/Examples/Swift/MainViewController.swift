//
//  ViewController.swift
//  OHHTTPStubsDemo
//
//  Created by Olivier Halligon on 18/04/2015.
//  Copyright (c) 2015 AliSoftware. All rights reserved.
//

import UIKit
import OHHTTPStubs

class MainViewController: UIViewController {

    ////////////////////////////////////////////////////////////////////////////////
    // MARK: - Outlets
    
    @IBOutlet var delaySwitch: UISwitch!
    @IBOutlet var textView: UITextView!
    @IBOutlet var installTextStubSwitch: UISwitch!
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var installImageStubSwitch: UISwitch!

    ////////////////////////////////////////////////////////////////////////////////
    // MARK: - Init & Dealloc
    
    override func viewDidLoad() {
        super.viewDidLoad()

        installTextStub(self.installTextStubSwitch)
        installImageStub(self.installImageStubSwitch)
        HTTPStubs.onStubActivation { (request: URLRequest, stub: HTTPStubsDescriptor, response: HTTPStubsResponse) in
            print("[OHHTTPStubs] Request to \(request.url!) has been stubbed with \(String(describing: stub.name))")
        }
    }

    ////////////////////////////////////////////////////////////////////////////////
    // MARK: - Global stubs activation

    @IBAction func toggleStubs(_ sender: UISwitch) {
        HTTPStubs.setEnabled(sender.isOn)
        self.delaySwitch.isEnabled = sender.isOn
        self.installTextStubSwitch.isEnabled = sender.isOn
        self.installImageStubSwitch.isEnabled = sender.isOn
        
        let state = sender.isOn ? "and enabled" : "but disabled"
        print("Installed (\(state)) stubs: \(HTTPStubs.allStubs())")
    }
    

    
    ////////////////////////////////////////////////////////////////////////////////
    // MARK: - Text Download and Stub
    
    
    @IBAction func downloadText(_ sender: UIButton) {
        sender.isEnabled = false
        self.textView.text = nil
        
        let urlString = "http://www.opensource.apple.com/source/Git/Git-26/src/git-htmldocs/git-commit.txt?txt"
        let req = URLRequest(url: URL(string: urlString)!)

        NSURLConnection.sendAsynchronousRequest(req, queue: OperationQueue.main) { (_, data, _) in
            sender.isEnabled = true
            if let receivedData = data, let receivedText = NSString(data: receivedData, encoding: String.Encoding.ascii.rawValue) {
                self.textView.text = receivedText as String
            }
        }
    }

    weak var textStub: HTTPStubsDescriptor?
    @IBAction func installTextStub(_ sender: UISwitch) {
        if sender.isOn {
            // Install
            let stubPath = OHPathForFile("stub.txt", type(of: self))
            textStub = stub(condition: isExtension("txt")) { [weak self] _ in
                let useDelay = DispatchQueue.main.sync { self?.delaySwitch.isOn ?? false }
                return fixture(filePath: stubPath!, headers: ["Content-Type":"text/plain"])
                    .requestTime(useDelay ? 2.0 : 0.0, responseTime:OHHTTPStubsDownloadSpeedWifi)
            }
            textStub?.name = "Text stub"
        } else {
            // Uninstall
            HTTPStubs.removeStub(textStub!)
        }
    }
    
    
    ////////////////////////////////////////////////////////////////////////////////
    // MARK: - Image Download and Stub
    
    @IBAction func downloadImage(_ sender: UIButton) {
        sender.isEnabled = false
        self.imageView.image = nil

        let urlString = "http://images.apple.com/support/assets/images/products/iphone/hero_iphone4-5_wide.png"
        let req = URLRequest(url: URL(string: urlString)!)

        NSURLConnection.sendAsynchronousRequest(req, queue: OperationQueue.main) { (_, data, _) in
            sender.isEnabled = true
            if let receivedData = data {
                DispatchQueue.main.async {
                    self.imageView.image = UIImage(data: receivedData)
                }
            }
        }
    }
    
    weak var imageStub: HTTPStubsDescriptor?
    @IBAction func installImageStub(_ sender: UISwitch) {
        if sender.isOn {
            // Install
            let stubPath = OHPathForFile("stub.jpg", type(of: self))
            imageStub = stub(condition: isExtension("png") || isExtension("jpg") || isExtension("gif")) { [weak self] _ in
                let useDelay = DispatchQueue.main.sync { self?.delaySwitch.isOn ?? false }
                return fixture(filePath: stubPath!, headers: ["Content-Type":"image/jpeg"])
                    .requestTime(useDelay ? 2.0 : 0.0, responseTime: OHHTTPStubsDownloadSpeedWifi)
            }
            imageStub?.name = "Image stub"
        } else {
            // Uninstall
            HTTPStubs.removeStub(imageStub!)
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////////
    // MARK: - Cleaning
    
    @IBAction func clearResults() {
        self.textView.text = ""
        self.imageView.image = nil
    }
    
}
