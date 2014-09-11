//
//  ViewController.swift
//  VideoSketch
//
//  Created by Evgeniy Kapralov on 11/09/14.
//  Copyright (c) 2014 Kapralos Software. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    var oglView : RenderView?
                            
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        oglView = RenderView(frame: self.view.bounds)
        view.addSubview(oglView!)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

