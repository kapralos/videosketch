//
//  ViewController.swift
//  VideoSketch
//
//  Created by Evgeniy Kapralov on 11/09/14.
//  Copyright (c) 2014 Kapralos Software. All rights reserved.
//

import UIKit

class ViewController: UIViewController, VideoProcessorDelegate {
    var videoProcessor = VideoProcessor()
    
    let debugViewWidth : CGFloat = 100.0
    let debugViewHeight : CGFloat = 40.0
    let debugViewPadding : CGFloat = 10.0
    var debugView : DebugInfoView?
    
    var oglView : RenderView?
    @IBOutlet weak var recordButton : UIButton!
    var backgroundRecordingId = UIBackgroundTaskIdentifier()
    
    var needShowDebugInfo = true
    var showDebugInfo : Bool
    {
        get
        {
            return needShowDebugInfo
        }
        set
        {
            needShowDebugInfo = newValue
            debugView?.hidden = !needShowDebugInfo;
        }
    }
                            
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        videoProcessor.delegate = self
        videoProcessor.setupAndStartCaptureSession()
        
        oglView = RenderView()
        oglView?.transform = videoProcessor.transformToOrientation(AVCaptureVideoOrientation.Portrait)
        view.addSubview(oglView!)
        var bounds = CGRect();
        bounds.size = self.view.convertRect(self.view.bounds, toView:oglView!).size;
        oglView?.bounds = bounds;
        oglView?.center = CGPointMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0);
        
        
        debugView = DebugInfoView(frame:CGRect(x: debugViewPadding, y: self.view.bounds.height - debugViewHeight - debugViewPadding, width: debugViewWidth, height: debugViewHeight))
        debugView?.updateResolution(width: videoProcessor.videoDimensions.width, height: videoProcessor.videoDimensions.height)
        debugView?.updateFps(fps: videoProcessor.videoFrameRate)
        view.addSubview(debugView!)
        
        view.bringSubviewToFront(recordButton)
    }
    
    override func viewWillAppear(animated: Bool)
    {
        super.viewWillAppear(animated)
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: Selector("applicationDidBecomeActive:"), name: UIApplicationDidBecomeActiveNotification, object: UIApplication.sharedApplication())
        notificationCenter.addObserver(self, selector: Selector("deviceOrientationDidChange"), name: UIDeviceOrientationDidChangeNotification, object: nil)
        UIDevice.currentDevice().beginGeneratingDeviceOrientationNotifications()
        
        videoProcessor.resumeCaptureSession()
    }
    
    override func viewWillDisappear(animated: Bool)
    {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
        videoProcessor.pauseCaptureSession()
    }
    
    override func finalize()
    {
        super.finalize()
        videoProcessor.stopCaptureSession()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func toggleRecording(sender:AnyObject!)
    {
        recordButton.enabled = false
        if videoProcessor.recording
        {
            videoProcessor.stopRecording()
        }
        else
        {
            videoProcessor.startRecording()
        }
    }
    
    // MARK: - Notifications
    func deviceOrientationDidChange()
    {
        let orientation = UIDevice.currentDevice().orientation
        if UIDeviceOrientationIsPortrait(orientation) || UIDeviceOrientationIsLandscape(orientation)
        {
            videoProcessor.referenceOrientation = convertToVideoOrientation(orientation)
        }
    }
    
    func applicationDidBecomeActive(application:UIApplication)
    {
        videoProcessor.resumeCaptureSession()
    }

    // MARK: - VideoProcessorDelegate
    func pixelBufferReadyForDisplay(pixelBuffer: CVPixelBufferRef)
    {
        if UIApplication.sharedApplication().applicationState != UIApplicationState.Background
        {
            oglView?.displayPixelBuffer(pixelBuffer)
        }
    }
    
    func recordingWillStart()
    {
        dispatch_async(dispatch_get_main_queue(),
        {
            self.recordButton.enabled = false
            // TODO: localization
            self.recordButton.setTitle("Stop", forState: UIControlState.Normal)
            
            UIApplication.sharedApplication().idleTimerDisabled = true
            self.backgroundRecordingId = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({})
        })
    }
    
    func recordingDidStart()
    {
        dispatch_async(dispatch_get_main_queue(),
        {
            self.recordButton.enabled = true
        })
    }
    
    func recordingWillStop()
    {
        dispatch_async(dispatch_get_main_queue(),
        {
            // TODO: localization
            self.recordButton.setTitle("Record", forState: UIControlState.Normal)
            self.recordButton.enabled = false
            self.videoProcessor.pauseCaptureSession()
        })
    }
    
    func recordingDidStop()
    {
        dispatch_async(dispatch_get_main_queue(),
        {
            self.videoProcessor.resumeCaptureSession()
            self.recordButton.enabled = true
            UIApplication.sharedApplication().idleTimerDisabled = false
            UIApplication.sharedApplication().endBackgroundTask(self.backgroundRecordingId)
            self.backgroundRecordingId = UIBackgroundTaskInvalid
        })
    }
    
    func notifyError(error: NSError)
    {
        dispatch_async(dispatch_get_main_queue(),
        {
            // TODO: localize
            let message = "Code: " + String(error.code) + "\nDomain: " + error.domain + "\nDescription: " + error.description
            let alert = UIAlertView(title: "Error", message: message, delegate: self, cancelButtonTitle: "Ok")
            alert.show()
        })
    }
}

