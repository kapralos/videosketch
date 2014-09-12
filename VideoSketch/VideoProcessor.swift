//
//  VideoProcessor.swift
//  VideoSketch
//
//  Created by Evgeniy Kapralov on 11/09/14.
//  Copyright (c) 2014 Kapralos Software. All rights reserved.
//

import AVFoundation
import CoreMedia
import MobileCoreServices
import AssetsLibrary

public protocol VideoProcessorDelegate
{
    func pixelBufferReadyForDisplay(pixelBuffer: CVPixelBufferRef)
    func recordingWillStart()
    func recordingDidStart()
    func recordingWillStop()
    func recordingDidStop()
}

public class VideoProcessor : NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate
{
    public var delegate : VideoProcessorDelegate?
    
    var previousSecondTimestemps : [CMTime] = []
    var videoFrameRate : Float64 = 0.0
    var videoDimensions : CMVideoDimensions = CMVideoDimensions(width: 0, height: 0)
    var videoType : CMVideoCodecType = CMVideoCodecType()
    
    var captureSession : AVCaptureSession?
    var audioConnection : AVCaptureConnection?
    var videoConnection : AVCaptureConnection?
    var previewBufferQueue : CMBufferQueueRef?
    var referenceOrientation : AVCaptureVideoOrientation = .Portrait
    private var videoOrientation = AVCaptureVideoOrientation.Portrait
    
    var movieUrl : NSURL = NSURL.fileURLWithPath(NSTemporaryDirectory() + "movie.mov")
    var assetWriter : AVAssetWriter?
    var assetWriterAudioIn : AVAssetWriterInput?
    var assetWriterVideoIn : AVAssetWriterInput?
    let movieWritingQueue : dispatch_queue_t = dispatch_queue_create("MovieWriterQueue", DISPATCH_QUEUE_SERIAL)
    
    var readyToRecordAudio : Bool = false
    var readyToRecordVideo : Bool = false
    var recordingWillBeStarted : Bool = false
    var recordingWillBeStopped : Bool = false
    var recording : Bool = false

    // MARK: - Utils
    private func calculateFramerateAtTimestamp(timestamp : CMTime)
    {
        previousSecondTimestemps.append(timestamp)
        let oneSecAgo = CMTimeSubtract(timestamp, CMTimeMake(1, 1))
        previousSecondTimestemps = previousSecondTimestemps.filter({ CMTimeCompare($0, oneSecAgo) < 0 })
        
        let newRate = Float64(previousSecondTimestemps.count)
        videoFrameRate = (videoFrameRate + newRate) / 2.0
    }
    
    private func removeFile(fileUrl: NSURL)
    {
        let fileManager = NSFileManager.defaultManager()
        let path = fileUrl.path
        if fileManager.fileExistsAtPath(path)
        {
            var error : NSError? = nil
            var success = fileManager.removeItemAtPath(path, error: &error)
            if !success
            {
                showError(error!)
            }
        }
    }
    
    private func angleOffsetToOrientation(orientation: AVCaptureVideoOrientation) -> CGFloat
    {
        var angle = 0.0
        
        switch orientation
        {
            case .LandscapeLeft:
                angle = M_PI / 2.0
                break
            case .LandscapeRight:
                angle = -M_PI / 2.0
                break
            case .PortraitUpsideDown:
                angle = M_PI
                break
            default:
                break
        }
        
        return CGFloat(angle)
    }
    
    private func transformToOrientation(orientation: AVCaptureVideoOrientation) -> CGAffineTransform
    {
        var transform = CGAffineTransformIdentity
        
        let orientationAngleOffset = angleOffsetToOrientation(orientation)
        let videoOrientationAngleOffset = angleOffsetToOrientation(videoOrientation)
        transform = CGAffineTransformMakeRotation(orientationAngleOffset - videoOrientationAngleOffset)
        
        return transform
    }
    
    // MARK: - Recording
    private func saveMovieToCameraRoll()
    {
        let assetLibrary = ALAssetsLibrary()
        assetLibrary.writeVideoAtPathToSavedPhotosAlbum(movieUrl, completionBlock: {
            (url: NSURL!, error: NSError!) -> Void in
            if error != nil
            {
                self.showError(error)
            }
            else
            {
                self.removeFile(url)
            }
            
            dispatch_async(self.movieWritingQueue, {
                self.recordingWillBeStopped = false
                self.recording = false
                self.delegate?.recordingDidStop()
            })
        })
    }
    
    private func writeSampleBuffer(sampleBuffer: CMSampleBufferRef, ofType type: NSString)
    {
        if assetWriter?.status == AVAssetWriterStatus.Unknown
        {
            if assetWriter?.startWriting() == true
            {
                assetWriter!.startSessionAtSourceTime(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            }
        }
        else if assetWriter?.status == AVAssetWriterStatus.Writing
        {
            if type == AVMediaTypeVideo && assetWriterVideoIn?.readyForMoreMediaData == true
            {
                if !assetWriterVideoIn!.appendSampleBuffer(sampleBuffer)
                {
                    showError(assetWriter!.error)
                }
            }
            else if type == AVMediaTypeAudio && assetWriterAudioIn?.readyForMoreMediaData == true
            {
                if !assetWriterAudioIn!.appendSampleBuffer(sampleBuffer)
                {
                    showError(assetWriter!.error)
                }
            }
        }
    }
    
    private func setupAssetWriterAudioIn(formatDescription: CMFormatDescriptionRef) -> Bool
    {
        let audioFormatDescription = convertToAudioDescription(formatDescription).takeUnretainedValue()
        let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDescription)
        
        var aclSize : UInt = 0
        let channelLayout = CMAudioFormatDescriptionGetChannelLayout(audioFormatDescription, &aclSize)
        var channelLayoutData : NSData?
        if channelLayout != nil && aclSize > 0
        {
            channelLayoutData = NSData(bytes: channelLayout, length: Int(aclSize))
        }
        else
        {
            channelLayoutData = NSData()
        }
        
        let numChannels : AnyObject = UInt(asbd.memory.mChannelsPerFrame) as AnyObject
        let audioCompressionSettings : [NSObject:AnyObject] = [AVFormatIDKey:kAudioFormatMPEG4AAC as AnyObject, AVSampleRateKey:asbd.memory.mSampleRate as AnyObject, AVEncoderBitRatePerChannelKey:64000 as AnyObject, AVNumberOfChannelsKey:numChannels, AVChannelLayoutKey:channelLayoutData as AnyObject]
        if (assetWriter?.canApplyOutputSettings(audioCompressionSettings, forMediaType: AVMediaTypeAudio) == true)
        {
            assetWriterAudioIn = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioCompressionSettings)
            assetWriterAudioIn?.expectsMediaDataInRealTime = true
            if assetWriter!.canAddInput(assetWriterAudioIn)
            {
                assetWriter!.addInput(assetWriterAudioIn!)
            }
            else
            {
                NSLog("unable to add audio input")
                return false
            }
        }
        else
        {
            NSLog("unable to apply audio settings")
            return false
        }
        
        return true
    }
    
    private func setupAssetWriterVideoIn(formatDescription: CMFormatDescriptionRef) -> Bool
    {
        let dimensions = getVideoDimensions(formatDescription)
        
        // TODO: implement custom bitrate
        let bitrate = 11.4
        let bitsPerSecond = Int(Double(dimensions.width) * Double(dimensions.height) * bitrate)
        
        let videoCompressionSettings : [NSObject:AnyObject] = [AVVideoCodecKey:AVVideoCodecH264,
            AVVideoWidthKey:Int(dimensions.width) as AnyObject,
            AVVideoHeightKey:Int(dimensions.height) as AnyObject,
            AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:bitsPerSecond, AVVideoMaxKeyFrameIntervalKey:30] as AnyObject]
        if assetWriter?.canApplyOutputSettings(videoCompressionSettings, forMediaType: AVMediaTypeVideo) == true
        {
            assetWriterVideoIn = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoCompressionSettings)
            assetWriterVideoIn?.expectsMediaDataInRealTime = true
            assetWriterVideoIn?.transform = transformToOrientation(referenceOrientation)
            if assetWriter!.canAddInput(assetWriterVideoIn)
            {
                assetWriter!.addInput(assetWriterVideoIn!)
            }
            else
            {
                NSLog("unable to add video input")
                return false
            }
        }
        else
        {
            NSLog("unable to apply video settings")
            return false
        }
        
        return true
    }
    
    public func startRecording()
    {
        dispatch_async(movieWritingQueue, {
            if self.recording || self.recordingWillBeStarted
            {
                return
            }
            
            self.recordingWillBeStarted = true
            self.delegate?.recordingWillStart()
            
            self.removeFile(self.movieUrl)
            
            var error : NSError?
            self.assetWriter = AVAssetWriter(URL: self.movieUrl, fileType: kUTTypeQuickTimeMovie as NSString, error: &error)
            if error != nil
            {
                self.showError(error!)
            }
        })
    }
    
    public func stopRecording()
    {
        dispatch_async(movieWritingQueue, {
            if !self.recording || self.recordingWillBeStopped
            {
                return
            }
            
            self.recordingWillBeStopped = true
            self.delegate?.recordingWillStop()
            
            self.assetWriter?.finishWritingWithCompletionHandler
            {
                self.assetWriter = nil
                self.readyToRecordAudio = false
                self.readyToRecordVideo = false
                self.saveMovieToCameraRoll()
            }
            
            if self.assetWriter?.status == AVAssetWriterStatus.Failed
            {
                self.showError(self.assetWriter!.error)
            }
        })
    }
    
    // MARK: - Capture
    public func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!)
    {
        let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)
        
        if videoConnection != nil && connection == videoConnection!
        {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            calculateFramerateAtTimestamp(timestamp)
            
            if videoDimensions.width == 0 && videoDimensions.height == 0
            {
                videoDimensions = getVideoDimensions(formatDescription)
            }
            
            if videoType == 0
            {
                videoType = CMFormatDescriptionGetMediaSubType(formatDescription)
            }
            
            let err = CMBufferQueueEnqueue(previewBufferQueue!, sampleBuffer)
            if err == 0
            {
                dispatch_async(dispatch_get_main_queue(), {
                    var sbuf = CMBufferQueueGetHead(self.previewBufferQueue!)
                    if sbuf != nil
                    {
                        let pixelBuffer = convertToPixelBuffer(CMSampleBufferGetImageBuffer(sampleBuffer)).takeUnretainedValue()
                        self.delegate?.pixelBufferReadyForDisplay(pixelBuffer)
                    }
                })
            }
            
            dispatch_async(movieWritingQueue, {
                if self.assetWriter != nil
                {
                    let wasReadyToRecord = self.readyToRecordVideo && self.readyToRecordAudio
                    
                    if (self.videoConnection != nil && connection == self.videoConnection!)
                    {
                        if !self.readyToRecordVideo
                        {
                            self.readyToRecordVideo = self.setupAssetWriterVideoIn(formatDescription)
                        }
                        
                        if self.readyToRecordVideo
                        {
                            self.writeSampleBuffer(sampleBuffer, ofType: AVMediaTypeVideo)
                        }
                    }
                    else if (self.audioConnection != nil && connection == self.audioConnection!)
                    {
                        if !self.readyToRecordAudio
                        {
                            self.readyToRecordAudio = self.setupAssetWriterAudioIn(formatDescription)
                        }
                        
                        if self.readyToRecordAudio
                        {
                            self.writeSampleBuffer(sampleBuffer, ofType: AVMediaTypeAudio)
                        }
                    }
                    
                    let isReadyToRecord = self.readyToRecordAudio && self.readyToRecordVideo
                    if !wasReadyToRecord && isReadyToRecord
                    {
                        self.recordingWillBeStarted = false
                        self.recording = true
                        self.delegate?.recordingDidStart()
                    }
                }
            })
        }
    }
    
    private func videoDeviceWithPosition(position: AVCaptureDevicePosition) -> AVCaptureDevice?
    {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for device in devices
        {
            // TODO: find less ugly way to convert
            let dev : AVCaptureDevice? = device as AnyObject? as? AVCaptureDevice
            if (dev!.position) == position
            {
                return dev
            }
        }
        
        return nil
    }
    
    private func audioDevice() -> AVCaptureDevice?
    {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeAudio)
        if devices.count > 0
        {
            return devices[0] as AnyObject? as? AVCaptureDevice
        }
        
        return nil
    }
    
    private func setupCaptureSession() -> Bool
    {
        captureSession = AVCaptureSession()
        
        if let audioDev = audioDevice()
        {
            let audioIn = AVCaptureDeviceInput(device: audioDev, error: nil)
            if captureSession?.canAddInput(audioIn) == true
            {
                captureSession!.addInput(audioIn)
            }
        }
        
        let audioOut = AVCaptureAudioDataOutput()
        let audioCaptureQueue = dispatch_queue_create("audioCaptureQueue", DISPATCH_QUEUE_SERIAL)
        audioOut.setSampleBufferDelegate(self, queue: audioCaptureQueue)
        if captureSession?.canAddOutput(audioOut) == true
        {
            captureSession!.addOutput(audioOut)
        }
        audioConnection = audioOut.connectionWithMediaType(AVMediaTypeAudio)
        
        // TODO: implement video input switch
        if let videoDev = videoDeviceWithPosition(AVCaptureDevicePosition.Back)
        {
            let videoIn = AVCaptureDeviceInput(device: videoDev, error: nil)
            if captureSession?.canAddInput(videoIn) == true
            {
                captureSession!.addInput(videoIn)
            }
        }
        
        let videoOut = AVCaptureVideoDataOutput()
        let videoCaptureQueue = dispatch_queue_create("videoCaptureQueue", DISPATCH_QUEUE_SERIAL)
        videoOut.alwaysDiscardsLateVideoFrames = true
        videoOut.videoSettings = [kCVPixelBufferPixelFormatTypeKey:kCVPixelFormatType_32BGRA as AnyObject]
        videoOut.setSampleBufferDelegate(self, queue: videoCaptureQueue)
        if captureSession?.canAddOutput(videoOut) == true
        {
            captureSession!.addOutput(videoOut)
        }
        videoConnection = videoOut.connectionWithMediaType(AVMediaTypeVideo)
        videoOrientation = videoConnection!.videoOrientation
        
        return true
    }
    
    private func captureSessionStoppedRunning(#notification:NSNotification)
    {
        dispatch_async(movieWritingQueue, {
            if self.recording
            {
                self.stopRecording()
            }
        })
    }
    
    public func setupAndStartCaptureSession()
    {
        // TODO: how to implement it simpler?
        let err = createBufferQueue(previewBufferQueue)
        if err != 0
        {
            showError(NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil))
            return
        }
        
        if captureSession == nil
        {
            setupCaptureSession()
        }
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("captureSessionStoppedRunning(notification:)"), name: AVCaptureSessionDidStopRunningNotification, object: captureSession)
        
        if captureSession?.running == false
        {
            captureSession?.startRunning()
        }
    }
    
    public func stopCaptureSession()
    {
        if captureSession != nil
        {
            captureSession!.stopRunning()
            NSNotificationCenter.defaultCenter().removeObserver(self)
            captureSession = nil
        }
        
        if previewBufferQueue != nil
        {
            previewBufferQueue = nil
        }
    }
    
    public func pauseCaptureSession()
    {
        if captureSession?.running == true
        {
            captureSession?.stopRunning()
        }
    }
    
    public func resumeCaptureSession()
    {
        if captureSession?.running == false
        {
            captureSession?.startRunning()
        }
    }
    
    // MARK: - Errors
    private func showError(error: NSError)
    {
        // TODO: show error popup
        #if DEBUG
            NSLog("%@", error)
        #endif
    }
}