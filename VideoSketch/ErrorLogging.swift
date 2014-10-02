//
//  ErrorLogging.swift
//  VideoSketch
//
//  Created by Evgeniy Kapralov on 13/09/14.
//  Copyright (c) 2014 Kapralos Software. All rights reserved.
//

import Foundation

public func DebugLog(format: String, _ file: String = __FILE__, _ function: String = __FUNCTION__, _ line: Int = __LINE__)
{
    #if DEBUG
        let now = NSDate()
        var formatter = NSDateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm:ss.SSS"
        println("\(formatter.stringFromDate(now)): \(file.lastPathComponent):\(line) \(function): \(format)")
    #endif
}
