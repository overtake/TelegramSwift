//
//  VideoRecorderPipeline.swift
//  Telegram
//
//  Created by keepcoder on 27/09/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import Accelerate
import TelegramCoreMac
import TGUIKit


private let videoCameraRetainedBufferCount:Int = 16;




class VideoRecorderPipeline : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, TGVideoCameraMovieRecorderDelegate, AVCaptureAudioDataOutputSampleBufferDelegate  {
    
    
    func movieRecorderDidFinishPreparing(_ recorder: TGVideoCameraMovieRecorder!) {
        
    }
    
    func movieRecorder(_ recorder: TGVideoCameraMovieRecorder!, didFailWithError error: Error!) {
        
    }
    
    func movieRecorderDidFinishRecording(_ recorder: TGVideoCameraMovieRecorder!) {
        liveUploading?.fileDidChangedSize(true)
        status = .finishRecording(path: url.path, duration: resultDuration, id: liveUploading?.id, thumb: thumbnail)
    }
    
    
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    private var videoConnection:AVCaptureConnection?
    private var videoDevice: AVCaptureDevice?
    
    private var audioDeviceInput: AVCaptureDeviceInput?
    private let audioOutput = AVCaptureAudioDataOutput()
    private var audioConnection:AVCaptureConnection?
    private var audioDevice: AVCaptureDevice?

    
    private var outputVideoFormatDescription: CMFormatDescription?
    private var outputAudioFormatDescription: CMFormatDescription?
    
    private var previousPixelBuffer: CVPixelBuffer?
    private var repeatingCount: Int32 = 0
    
    private(set) var thumbnail:CGImage?
    
    let session: AVCaptureSession = AVCaptureSession()
    
    private var status: VideoCameraRecordingStatus = .idle {
        didSet {
            statePromise.set(status)
        }
    }
    
    let statePromise:ValuePromise<VideoCameraRecordingStatus> = ValuePromise(.idle, ignoreRepeated: true)
    let powerAndDuration: Promise<(Float, Double)> = Promise()
    
    private let renderer:TGVideoCameraGLRenderer = TGVideoCameraGLRenderer()
    private var renderingEnabled: Bool = false

    private var recorder: TGVideoCameraMovieRecorder!
    
    
    private let url:URL
    
    private var resultDuration: Int = 0
    private var startTimeInterval: TimeInterval = 0

    private static let queue: Queue = Queue(name: "org.telegram.InstantVideoQueue")
    
    private let startRecordAfterAudioBuffer:Atomic<Bool> = Atomic(value: false)

    static let videoMessageMaxDuration: Double = 60

    private let liveUploading: PreUploadManager?
    init(url:URL, liveUploading: PreUploadManager?) {
        self.url = url
        self.liveUploading = liveUploading
        super.init()
        
        recorder = TGVideoCameraMovieRecorder(url: url, delegate: self, callbackQueue: VideoRecorderPipeline.queue.queue)
        
        renderer.orientation = .portrait
        renderer.mirror = true
        
        if session.canSetSessionPreset(.vga640x480) {
            session.sessionPreset = .vga640x480
        } else {
            session.sessionPreset = .medium
        }
        
        if let videoDevice = AVCaptureDevice.default(for: .video) {
            setSelectedVideoDevice(videoDevice)
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                
                setSelectedAudioDevice(audioDevice)
            }
        } else if let videoDevice = AVCaptureDevice.default(for: .muxed) {
            setSelectedVideoDevice(videoDevice)
        }
        
        videoOutput.alwaysDiscardsLateVideoFrames = false

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferIOSurfacePropertiesKey as String: [:], kCVPixelBufferWidthKey as String: 500, kCVPixelBufferHeightKey as String: 500]
        
        videoOutput.setSampleBufferDelegate(self, queue: VideoRecorderPipeline.queue.queue)
        session.addOutput(videoOutput)

        audioOutput.setSampleBufferDelegate(self, queue: VideoRecorderPipeline.queue.queue)

        //averagePowerForChannel
        
        
        session.addOutput(audioOutput)
        
        
        videoConnection = videoOutput.connection(with: .video)
        audioConnection = audioOutput.connection(with: .audio)
        
       
        
        
        _configureFps()
    }
    
    private func _configureFps() {
        
        //let frameDuration = CMTimeMake(1, 30)
        
        if let videoDevice = videoDevice {
            _reconfigureDevice(videoDevice, with: { device in
               // device.activeVideoMaxFrameDuration = frameDuration
               // device.activeVideoMinFrameDuration = frameDuration
            })
        }
    }
    
    private func _reconfigureDevice(_ device: AVCaptureDevice, with block: (AVCaptureDevice)-> Void) {
        try? device.lockForConfiguration()
        block(device)
        device.unlockForConfiguration()
    }
    

    private func setSelectedAudioDevice(_ device: AVCaptureDevice) {
        self.audioDevice = device
        session.beginConfiguration()
        if let audioDeviceInput = audioDeviceInput {
            session.removeInput(audioDeviceInput)
            self.audioDeviceInput = nil
        }
        if let audioDeviceInput = try? AVCaptureDeviceInput(device: device)  {
            if !device.supportsSessionPreset(session.sessionPreset) {
                session.sessionPreset = .high
            }
            session.addInput(audioDeviceInput)
            self.audioDeviceInput = audioDeviceInput
        }
        session.commitConfiguration()
    }
    
    private func setSelectedVideoDevice(_ device: AVCaptureDevice) {
        self.videoDevice = device
        
        session.beginConfiguration()
        if let videoDeviceInput = videoDeviceInput {
            session.removeInput(videoDeviceInput)
            self.videoDeviceInput = nil
        }
        if let videoDeviceInput = try? AVCaptureDeviceInput(device: device)  {
            if !device.supportsSessionPreset(session.sessionPreset) {
                session.sessionPreset = .high
            }
            session.addInput(videoDeviceInput)
            self.videoDeviceInput = videoDeviceInput
        }
        session.commitConfiguration()
    }
  
    
    
    
    private func setupVideoPipelineWithInputFormatDescription(_ inputFormatDescription: CMFormatDescription) {
        renderer.prepareForInput(with: inputFormatDescription, outputRetainedBufferCountHint: videoCameraRetainedBufferCount);
        self.outputVideoFormatDescription = renderer.outputFormatDescription
        
        self.startRecording()
    }
    

   
    private let skip:Atomic<Int32> = Atomic(value: 0)
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        if self.skip.modify({min($0 + 1, 35)}) < 35 {
            return
        }
        
        if connection == self.videoConnection, let formatDescription = formatDescription {
            
            if self.outputVideoFormatDescription == nil {
                self.setupVideoPipelineWithInputFormatDescription(formatDescription)
            } else {
                self.renderVideoSampleBuffer(sampleBuffer)
            }
            
            
        } else if connection == self.audioConnection {
            self.outputAudioFormatDescription = formatDescription
            
            if startRecordAfterAudioBuffer.swap(false) {
                self.startRecording()
                return
            }
            
            recorder.appendAudioSampleBuffer(sampleBuffer)
            
            if renderingEnabled {
                let duration = Double(Date().timeIntervalSince1970 - startTimeInterval)
                for channel in connection.audioChannels {
                    let power = Float(mappingRange(Double(channel.averagePowerLevel), -60, 0, 0, 1))
                    powerAndDuration.set(.single((power, duration)))
                }
            }
        }
        liveUploading?.fileDidChangedSize(false)
    }
    

    
    private func renderVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        var renderedPixelBuffer: CVPixelBuffer? = nil
        let timestamp: CMTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if renderingEnabled, let sourcePixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {

            renderedPixelBuffer = renderer.copyRenderedPixelBuffer(sourcePixelBuffer).takeRetainedValue()
            
        }
        if let renderedPixelBuffer = renderedPixelBuffer {
            if thumbnail == nil {
                if let thumb = renderedPixelBuffer.cgImage {
                    status = .madeThumbnail(thumb)
                    thumbnail = thumb
                }
            }
            recorder?.appendVideoPixelBuffer(renderedPixelBuffer, withPresentationTime: timestamp)
        }
        
    }
    



    private func startRecording() {
        

        if outputAudioFormatDescription == nil {
            _ = startRecordAfterAudioBuffer.swap(true)
            return
        }

        renderingEnabled = true
        status = .recording
        startTimeInterval = Date().timeIntervalSince1970

        let audioSettings = TGMediaVideoConversionPresetSettings.audioSettings(for: TGMediaVideoConversionPresetVideoMessage)
        recorder.addAudioTrack(withSourceFormatDescription: outputAudioFormatDescription, settings: audioSettings)
        let size: CGSize = TGMediaVideoConversionPresetSettings.maximumSize(for: TGMediaVideoConversionPresetVideoMessage)
        let videoSettings = TGMediaVideoConversionPresetSettings.videoSettings(for: TGMediaVideoConversionPresetVideoMessage, dimensions: size)
        recorder.addVideoTrack(withSourceFormatDescription: outputVideoFormatDescription, transform: CGAffineTransform.identity, settings: videoSettings)
        
        recorder.prepareToRecord()
        
    }

    
    deinit {
        VideoRecorderPipeline.queue.sync {
            stopCapture()
            if case .recording = status {
                try? FileManager.default.removeItem(atPath: url.path)
            }
        }
    }

    
    func stop() {
        VideoRecorderPipeline.queue.async {
            if case .finishRecording = self.status {
                return
            }
            self.status = .stoppingRecording
            self.videoOutput.setSampleBufferDelegate(nil, queue: nil)
            self.audioOutput.setSampleBufferDelegate(nil, queue: nil)
            let duration = self.recorder.videoDuration()
            if !duration.isNaN && duration >= 0.5 {
                self.resultDuration = Int(ceil(duration))
                self.recorder.finishRecording()
            } else {
                self.dispose()
            }
        }
    }
    
    func stopCapture() {
        VideoRecorderPipeline.queue.async {
            self.session.stopRunning()
        }
    }
    
    func dispose() {
        VideoRecorderPipeline.queue.async {
            if case .finishRecording = self.status {
                return
            }
            self.status = .stopped(thumb: self.thumbnail)
            let duration = self.recorder.videoDuration()
            if !duration.isNaN {
                self.resultDuration = Int(ceil(duration))
            }
        }
    }
  
    
    func start() {
        VideoRecorderPipeline.queue.async {
            self.status = .startingRecording
            self.session.startRunning()
        }
    }
}
