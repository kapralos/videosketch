//
//  Helpers.h
//  VideoSketch
//
//  Created by Evgeniy Kapralov on 12/09/14.
//  Copyright (c) 2014 Kapralos Software. All rights reserved.
//

#ifndef VideoSketch_Helpers_h
#define VideoSketch_Helpers_h

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CMBufferQueue.h>

// Swift does not map very well to Cocoa C API. In this particular case it requires CMFormatDescriptionRef
// explicit conversion to CMAudioFormatDescriptionRef
CMAudioFormatDescriptionRef convertToAudioDescription(CMFormatDescriptionRef description);

CVPixelBufferRef convertToPixelBuffer(CVImageBufferRef buffer);

CMVideoDimensions getVideoDimensions(CMFormatDescriptionRef description);

OSStatus createBufferQueue(CMBufferQueueRef queue);

#endif
