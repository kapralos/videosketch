//
//  ErrorLogging.swift
//  VideoSketch
//
//  Created by Evgeniy Kapralov on 13/09/14.
//  Copyright (c) 2014 Kapralos Software. All rights reserved.
//

import Foundation

public func DebugLog(format: String, _ function: String = __FUNCTION__, _ line: Int = __LINE__)
{
    #if DEBUG
        println("\(function):\(line) - \(format)")
    #endif
}
