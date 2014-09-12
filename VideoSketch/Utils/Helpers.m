//
//  Helpers.m
//  VideoSketch
//
//  Created by Evgeniy Kapralov on 12/09/14.
//  Copyright (c) 2014 Kapralos Software. All rights reserved.
//

#import "Helpers.h"

CMAudioFormatDescriptionRef convertToAudioDescription(CMFormatDescriptionRef description)
{
    return (CMAudioFormatDescriptionRef)description;
}

CVPixelBufferRef convertToPixelBuffer(CVImageBufferRef buffer)
{
    return (CVPixelBufferRef)buffer;
}

CMVideoDimensions getVideoDimensions(CMFormatDescriptionRef description)
{
    if (description)
    {
        return CMVideoFormatDescriptionGetDimensions(description);
    }
    
    CMVideoDimensions res;
    res.width = 0;
    res.height = 0;
    return res;
}

OSStatus createBufferQueue(CMBufferQueueRef queue)
{
    return CMBufferQueueCreate(kCFAllocatorDefault, 1, CMBufferQueueGetCallbacksForUnsortedSampleBuffers(), &queue);
}
