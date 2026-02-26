//
//  Math.swift
//  GameEngine
//
//  Created by Mike Renoir on 08.01.2024.
//

import Foundation
import MetalKit

public var X_AXIS: simd_float3 {
    return simd_float3(1, 0, 0)
}
public var Y_AXIS: simd_float3 {
    return simd_float3(0, 1, 0)
}
public var Z_AXIS: simd_float3 {
    return simd_float3(0, 0, 1)
}

extension matrix_float4x4 {
    mutating func translate(direction: simd_float3) {
        var result = matrix_identity_float4x4
        
        let x:Float = direction.x
        let y: Float = direction.y
        let z: Float = direction.z
        
        result.columns = (
            simd_float4(1, 0, 0, 0),
            simd_float4(0, 1, 0, 0),
            simd_float4(0, 0, 1, 0),
            simd_float4(x, y, z, 1)
        )
        
        self = matrix_multiply(self, result)
    }
    mutating func scale(axis: simd_float3) {
        var result = matrix_identity_float4x4
        
        let x: Float = axis.x
        let y: Float = axis.y
        let z: Float = axis.z
        
        result.columns = (
            simd_float4(x, 0, 0, 0),
            simd_float4(0, y, 0, 0),
            simd_float4(0, 0, z, 0),
            simd_float4(0, 0, 0, 1)
        )
        
        self = matrix_multiply(self, result)
    }
    mutating func rotate(angle: Float, axis: simd_float3) {
        var result = matrix_identity_float4x4
        
        let x: Float = axis.x
        let y: Float = axis.y
        let z: Float = axis.z
        
        let c: Float = cos(angle)
        let s: Float = sin(angle)
        
        let mc = (1 - c)
        
        let r1c1: Float = x * x * mc + c
        let r2c1: Float = x * y * mc + z * s
        let r3c1: Float = x * z * mc - y * s
        let r4c1: Float = 0.0
        
        let r1c2: Float = y * x * mc - z * s
        let r2c2: Float = y * y * mc + c
        let r3c2: Float = y * z * mc + x * s
        let r4c2: Float = 0.0
        
        let r1c3: Float = z * x * mc + y * s
        let r2c3: Float = z * y * mc - x * s
        let r3c3: Float = z * z * mc + c
        let r4c3: Float = 0.0
        
        let r1c4: Float = 0.0
        let r2c4: Float = 0.0
        let r3c4: Float = 0.0
        let r4c4: Float = 1.0
        
        result.columns = (
            simd_float4(r1c1, r2c1, r3c1, r4c1),
            simd_float4(r1c2, r2c2, r3c2, r4c2),
            simd_float4(r1c3, r2c3, r3c3, r4c3),
            simd_float4(r1c4, r2c4, r3c4, r4c4)
        )
        
        self = matrix_multiply(self, result)
    }
    
    func perspective(degreesFov: Float, aspectRatio: Float, near: Float, far: Float) -> matrix_float4x4 {
        let fov = degreesFov.toRadians
        let t = tan(fov * 0.5)
        
        let x = 1 / (aspectRatio * t)
        let y = 1 / t
        let z = -((far + near) / (far - near))
        let w = -((2 * far * near) / (far - near))
        
        var result = matrix_identity_float4x4
        result.columns = (
            simd_float4(x, 0, 0, 0),
            simd_float4(0, y, 0, 0),
            simd_float4(0, 0, z, -1),
            simd_float4(0, 0, w, 0)
        )
        return result
    }
    
}

extension Float {
    var toRadians: Float {
        return self / 180 * .pi
    }
    var toDegrees: Float {
        return self * (180 / .pi)
    }
}
