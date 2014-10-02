//
//  Utils.swift
//  VideoSketch
//
//  Created by Evgeniy Kapralov on 18/09/14.
//  Copyright (c) 2014 Kapralos Software. All rights reserved.
//

import AVFoundation
import UIKit

public func convertToVideoOrientation(orientation : UIDeviceOrientation) -> AVCaptureVideoOrientation
{
    switch orientation
    {
        case .LandscapeLeft:
            return AVCaptureVideoOrientation.LandscapeLeft
        case .LandscapeRight:
            return AVCaptureVideoOrientation.LandscapeRight
        case .PortraitUpsideDown:
            return AVCaptureVideoOrientation.PortraitUpsideDown
        default:
            return AVCaptureVideoOrientation.Portrait
    }
}
