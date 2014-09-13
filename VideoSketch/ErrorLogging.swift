//
//  ErrorLogging.swift
//  VideoSketch
//
//  Created by Evgeniy Kapralov on 13/09/14.
//  Copyright (c) 2014 Kapralos Software. All rights reserved.
//

import Foundation

public func DebugLog(format: String, args: CVarArgType...)
{
    #if DEBUG
        NSLog("%@: %@ " + format, __LINE__, __FUNCTION__, args)
    #endif
}
