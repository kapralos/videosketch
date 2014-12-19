//
//  DebugInfoView.swift
//  VideoSketch
//
//  Created by Evgeniy Kapralov on 13/09/14.
//  Copyright (c) 2014 Kapralos Software. All rights reserved.
//

import UIKit

class DebugInfoView : UIView
{
    var resolutionLabel : UILabel?
    var fpsLabel : UILabel?
    
    required init(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    override required init(frame: CGRect)
    {
        super.init(frame: frame)
        
        resolutionLabel = UILabel(frame: CGRect(x: 0.0, y: 0.0, width: frame.width, height: frame.height / 2.0))
        resolutionLabel?.textAlignment = NSTextAlignment.Center
        resolutionLabel?.textColor = UIColor.whiteColor()
        self.addSubview(resolutionLabel!)
        
        fpsLabel = UILabel(frame: CGRect(x: 0.0, y: frame.height / 2.0, width: frame.width, height: frame.height / 2.0))
        fpsLabel?.textAlignment = NSTextAlignment.Center
        fpsLabel?.textColor = UIColor.whiteColor()
        self.addSubview(fpsLabel!)
    }
    
    func updateResolution(#width: Int32, height: Int32)
    {
        resolutionLabel?.text = String(width) + " x " + String(height)
    }
    
    func updateFps(fps: Float64)
    {
        fpsLabel?.text = String(format: "%.1f", fps) + " fps"
    }
}
