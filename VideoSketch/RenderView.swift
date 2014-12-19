//
//  RenderView.swift
//  VideoSketch
//
//  Created by Evgeniy Kapralov on 01/10/14.
//  Copyright (c) 2014 Kapralos Software. All rights reserved.
//

import Foundation
import UIKit
import OpenGLES
import CoreVideo
import QuartzCore

enum AttributeLocation : GLuint
{
    case ATTRIB_VERTEX = 0
    case ATTRIB_TEXTUREPOSITON = 1
}

extension GLuint
{
    init(_ attrLocation: AttributeLocation)
    {
        switch attrLocation {
            case .ATTRIB_VERTEX(let attrVertex):
                self = 0
            case .ATTRIB_TEXTUREPOSITON(let textPos):
                self = 1
        }
    }
}

public class RenderView : UIView
{
    var renderBufferWidth = 0
    var renderBufferHeight = 0
    
    private var oglContext = EAGLContext(API: .OpenGLES2)
    private var videoTextureCache : CVOpenGLESTextureCacheRef?
    
    private var frameBufferHandle : GLuint = 0
    private var colorBufferHandle : GLuint = 0
    private var renderProgram : GLuint = 0
    
    private let squareVertices : [GLfloat] = [
        -1.0, -1.0,
        1.0, -1.0,
        -1.0,  1.0,
        1.0,  1.0
    ]
    
    private let screenTextureVertices : [GLfloat] = [
        0.0, 1.0,
        1.0, 1.0,
        0.0, 0.0,
        1.0, 0.0
    ]
    
    required public init(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    public override init(frame: CGRect)
    {
        super.init(frame: frame)
        contentScaleFactor = UIScreen.mainScreen().scale
        
        var eaglLayer = layer as CAEAGLLayer
        eaglLayer.opaque = true
        eaglLayer.drawableProperties = [ kEAGLDrawablePropertyRetainedBacking:false as AnyObject, kEAGLDrawablePropertyColorFormat:kEAGLColorFormatRGBA8 as AnyObject ]
        let res = EAGLContext.setCurrentContext(oglContext)
    }
    
    public override init()
    {
        super.init()
    }
    
    deinit
    {
        if frameBufferHandle != 0 {
            glDeleteFramebuffers(1, &frameBufferHandle)
        }
        if colorBufferHandle != 0 {
            glDeleteRenderbuffers(1, &colorBufferHandle)
        }
        if renderProgram != 0 {
            glDeleteProgram(renderProgram)
        }
        
        if videoTextureCache != nil {
            CVOpenGLESTextureCacheFlush(videoTextureCache, 0)
            videoTextureCache = nil
        }
    }
    
    override public class func layerClass() -> AnyClass
    {
        return CAEAGLLayer.self
    }
    
    public func displayPixelBuffer(pixelBuffer: CVPixelBufferRef)
    {
        if frameBufferHandle == 0 {
            if !initializeBuffers() {
                DebugLog("Failed to initialize OpenGL buffers")
                return
            }
        }
        
        if videoTextureCache == nil {
            return
        }
        
        let frameWidth = CVPixelBufferGetWidth(pixelBuffer)
        let frameHeight = CVPixelBufferGetHeight(pixelBuffer)
        var textureRef : Unmanaged<CVOpenGLESTextureRef>?
        let err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, videoTextureCache!, pixelBuffer, nil, GLenum(GL_TEXTURE_2D), GLint(GL_RGBA), GLsizei(frameWidth), GLsizei(frameHeight), GLenum(GL_BGRA), GLenum(GL_UNSIGNED_BYTE), 0, &textureRef)
        if err != 0 || textureRef == nil
        {
            DebugLog("Failed CVOpenGLESTextureCacheCreateTextureFromImage: \(err)")
            return
        }
        
        let texture = textureRef!.takeUnretainedValue()
        glBindTexture(CVOpenGLESTextureGetTarget(texture), CVOpenGLESTextureGetName(texture))
        
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GL_LINEAR)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GL_CLAMP_TO_EDGE)
        glTexParameteri(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GL_CLAMP_TO_EDGE)
        
        bindScreenFramebuffer()
        renderWithSquareVertices(squareVertices, textureVertices: screenTextureVertices)
        
        glBindTexture(CVOpenGLESTextureGetTarget(texture), 0)
        textureRef?.release()
        CVOpenGLESTextureCacheFlush(videoTextureCache, 0)
    }
    
    private func bindScreenFramebuffer() {
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), frameBufferHandle)
        glViewport(0, 0, GLsizei(renderBufferWidth), GLsizei(renderBufferHeight))
    }
    
    // MARK: - Private
    private func readFile(name: String) -> [GLchar]?
    {
        let path = NSBundle.mainBundle().pathForResource(name, ofType: nil)
        var error : NSError?
        return String(contentsOfFile: path!, encoding: NSUTF8StringEncoding, error: &error)?.cStringUsingEncoding(NSUTF8StringEncoding)
    }
    
    private func initializeBuffers() -> Bool
    {
        var success = true
        
        glDisable(GLenum(GL_DEPTH_TEST))
        
        glGenFramebuffers(1, &frameBufferHandle)
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), frameBufferHandle)
        
        glGenRenderbuffers(1, &colorBufferHandle)
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), colorBufferHandle)
        
        oglContext.renderbufferStorage(Int(GL_RENDERBUFFER), fromDrawable: self.layer as CAEAGLLayer)
        
        var width : GLint = 0
        var height : GLint = 0
        glGetRenderbufferParameteriv(GLenum(GL_RENDERBUFFER), GLenum(GL_RENDERBUFFER_WIDTH), &width)
        renderBufferWidth = Int(width)
        glGetRenderbufferParameteriv(GLenum(GL_RENDERBUFFER), GLenum(GL_RENDERBUFFER_HEIGHT), &height)
        renderBufferHeight = Int(height)
        
        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_RENDERBUFFER), colorBufferHandle)
        if glCheckFramebufferStatus(GLenum(GL_FRAMEBUFFER)) != GLenum(GL_FRAMEBUFFER_COMPLETE) {
            DebugLog("Failure with framebuffer generation")
            success = false
        }
        
        var cache : Unmanaged<CVOpenGLESTextureCacheRef>?
        let err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, nil, oglContext, nil, &cache)
        if err == 0 && cache != nil {
            videoTextureCache = cache?.takeUnretainedValue()
        } else {
            DebugLog("Error at CVOpenGLESTextureCacheCreate: \(err)")
            success = false
        }
        
        let vertSrc = readFile("passThrough.vsh")
        let fragSrc = readFile("passThrough.fsh")
        if vertSrc != nil && fragSrc != nil {
            let attribLocations : [GLuint] = [ GLuint(.ATTRIB_VERTEX), GLuint(.ATTRIB_TEXTUREPOSITON) ]
            let attribNames : [[GLchar]] = [ "position".cStringUsingEncoding(NSUTF8StringEncoding)!, "textureCoordinate".cStringUsingEncoding(NSUTF8StringEncoding)! ]
            createProgram(vertSrc!, fragSrc!, attribNames, attribLocations, nil, nil, &renderProgram)
            if renderProgram == 0 {
                success = false
            }
        } else {
            DebugLog("Failed to read shader files")
            success = false
        }
        
        return success
    }
    
    private func renderWithSquareVertices(squareVertices:[GLfloat], textureVertices:[GLfloat])
    {
        glUseProgram(renderProgram)
        
        glVertexAttribPointer(GLuint(.ATTRIB_VERTEX), 2, GLenum(GL_FLOAT), 0, 0, squareVertices)
        glEnableVertexAttribArray(GLuint(.ATTRIB_VERTEX))
        glVertexAttribPointer(GLuint(.ATTRIB_TEXTUREPOSITON), 2, GLenum(GL_FLOAT), 0, 0, textureVertices)
        glEnableVertexAttribArray(GLuint(.ATTRIB_TEXTUREPOSITON))
        
        glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 4)
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), colorBufferHandle)
        oglContext.presentRenderbuffer(Int(GL_RENDERBUFFER))
    }
}
