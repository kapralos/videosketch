//
//  ShaderUtils.swift
//  VideoSketch
//
//  Created by Evgeniy Kapralov on 01/10/14.
//  Copyright (c) 2014 Kapralos Software. All rights reserved.
//

import Foundation
import OpenGLES

public func compileShader(target: GLenum, count: GLsizei, sources:  UnsafePointer<UnsafePointer<GLchar>>, shader: UnsafeMutablePointer<GLuint>) -> GLint
{
    var status: GLint = 0
    
    shader.memory = glCreateShader(target)
    glShaderSource(shader.memory, count, sources, nil)
    glCompileShader(shader.memory)
    glGetShaderiv(shader.memory, GLenum(GL_COMPILE_STATUS), &status)
    
    if status == 0 {
        DebugLog("Failed to compile shader: %d", shader.memory)
    }
    
    return status
}

public func linkProgram(program: GLuint) -> GLint
{
    var status : GLint = 0
    glLinkProgram(program)
    glGetProgramiv(program, GLenum(GL_LINK_STATUS), &status)
    if status == 0 {
        DebugLog("Failed to link program: %d", program)
    }
    
    return status
}

public func validateProgram(program: GLuint) -> GLint
{
    var status : GLint = 0
    glValidateProgram(program)
    glGetProgramiv(program, GLenum(GL_VALIDATE_STATUS), &status)
    if status == 0 {
        DebugLog("Failed to validate program: %d", program)
    }
    
    return status
}

public func createProgram(vertSource: UnsafePointer<GLchar>, fragSource: UnsafePointer<GLchar>, attribNames: ([[GLchar]])?, attribLocations: [GLuint]?, uniformNames: ([[GLchar]])?, uniformLocations: UnsafeMutablePointer<Int32>, program: UnsafeMutablePointer<GLuint>) -> GLint
{
    var prog = glCreateProgram()
    var status : GLint = 1
    var vertShader : GLuint = 0
    var fragShader : GLuint = 0
    
    var vertSrc : UnsafePointer<GLchar>? = vertSource
    status *= compileShader(GLenum(GL_VERTEX_SHADER), 1, &(vertSrc!), &vertShader)
    var fragSrc : UnsafePointer<GLchar>? = fragSource
    status *= compileShader(GLenum(GL_FRAGMENT_SHADER), 1, &(fragSrc!), &fragShader)
    glAttachShader(prog, vertShader)
    glAttachShader(prog, fragShader)

    if attribNames != nil && attribLocations != nil {
        for i in 0..<attribNames!.count {
            glBindAttribLocation(prog, attribLocations![i], attribNames![i])
        }
    }
    
    status *= linkProgram(prog)
    #if DEBUG
        status *= validateProgram(prog)
    #endif
    
    if status != 0
    {
        if uniformNames != nil {
            for i in 0..<uniformNames!.count {
                uniformLocations[i] = glGetUniformLocation(prog, uniformNames![i])
            }
        }
        
        program.memory = prog
    }
    
    if vertShader != 0 {
        glDeleteShader(vertShader)
    }
    if fragShader != 0 {
        glDeleteShader(fragShader)
    }
    
    return status
}
