//
//  Helpers.h
//  VideoSketch
//
//  Created by Evgeniy Kapralov on 12/09/14.
//  Copyright (c) 2014 Kapralos Software. All rights reserved.
//

#ifndef VideoSketch_Helpers_h
#define VideoSketch_Helpers_h

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CMBufferQueue.h>

// Swift does not map very well to Cocoa C API. In this particular case it requires CMFormatDescriptionRef
// explicit conversion to CMAudioFormatDescriptionRef
CMAudioFormatDescriptionRef convertToAudioDescription(CMFormatDescriptionRef description);

CVPixelBufferRef convertToPixelBuffer(CVImageBufferRef buffer);

AVCaptureVideoOrientation convertToVideoOrientation(UIDeviceOrientation orientation);

CMVideoDimensions getVideoDimensions(CMFormatDescriptionRef description);

CMBufferQueueRef createBufferQueue(OSStatus* status);

#endif
