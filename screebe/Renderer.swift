//
//  ViewController.swift
//  screebe
//
//  Created by Owen on 31.07.19.
//  Copyright © 2019 daven. All rights reserved.
//

import UIKit
import MetalKit

class Renderer: NSObject, MTKViewDelegate {
    private let _sampleCount = 4

    private var _device: MTLDevice!
    private var _commandQueue: MTLCommandQueue!
    
    private var _renderPipelineState: MTLRenderPipelineState!
    private var _renderPipelineDescriptor: MTLRenderPipelineDescriptor!
    
    private var _verticesBuffer: MTLBuffer!
    private var _verticesIndicesBuffer: MTLBuffer!
    private var _verticesInfosBuffer: MTLBuffer!
    private var _fragmentBuffer: MTLBuffer!
    
    private var _view: MTKView!
    private var _trianglesFlowManager: TrianglesFlowManager!
    
    init(_ mtkView: MTKView) {
        super.init()

        mtkView.device = MTLCreateSystemDefaultDevice()!
        mtkView.preferredFramesPerSecond = 120
        mtkView.sampleCount = _sampleCount
        _device = mtkView.device
        
        let library = _device.makeDefaultLibrary()!
        _renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        _renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "main_vertex")
        _renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "main_fragment")
        _renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        _renderPipelineDescriptor.sampleCount = _sampleCount

        do {
            _renderPipelineState = try _device.makeRenderPipelineState(descriptor: _renderPipelineDescriptor)
        } catch let error as NSError {
            print("error: \(error.localizedDescription)")
        }
        
        mtkView.clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1.0)
        mtkView.isOpaque = false

        _commandQueue = _device.makeCommandQueue()!
        _trianglesFlowManager = TrianglesFlowManager()
        _view = mtkView

        updateSize()
        updateVertices()

        mtkView.delegate = self
    }
    
    func touched(_ touches: Set<UITouch>, _ event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: nil)
            let vertex = Vertex(
                position: [Float(location.x), Float(location.y)]
                // pointSize: Float(touch.force) * 20 + 8
            )
            _trianglesFlowManager.addKeyVertex(vertex)
            updateVertices()
        }
    }
    
    func endTouch() {
        _trianglesFlowManager.stop()
        updateVertices()
    }

    func draw(in view: MTKView) {
        let verticesCommandBuffer = _commandQueue.makeCommandBuffer()!
        let verticesCommandEncoder = verticesCommandBuffer.makeRenderCommandEncoder(descriptor: view.currentRenderPassDescriptor!)!

        if _trianglesFlowManager.indices.count > 0 {
            verticesCommandEncoder.setRenderPipelineState(_renderPipelineState)
            verticesCommandEncoder.setVertexBuffer(_verticesInfosBuffer, offset: 0, index: 0)
            verticesCommandEncoder.setVertexBuffer(_verticesBuffer, offset: 0, index: 1)
            // verticesCommandEncoder.setTriangleFillMode(.lines)

            verticesCommandEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: _trianglesFlowManager!.indices.count,
                indexType: .uint32,
                indexBuffer: _verticesIndicesBuffer,
                indexBufferOffset: 0
            )
        }
        
        verticesCommandEncoder.endEncoding()
        verticesCommandBuffer.present(view.currentDrawable!)
        verticesCommandBuffer.commit()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        updateSize()
    }
    
    func updateVertices() {
        if _trianglesFlowManager.indices.count > 0 {
            _verticesIndicesBuffer = _device.makeBuffer(
                bytes: _trianglesFlowManager.indices,
                length: _trianglesFlowManager.indices.count * MemoryLayout<UInt32>.stride,
                options: .storageModeShared
            )
            _verticesBuffer = _device.makeBuffer(
                bytes: _trianglesFlowManager.triangleVertices,
                length: _trianglesFlowManager.triangleVertices.count * MemoryLayout<Vertex>.stride,
                options: .storageModeShared
            )
        }
    }
    
    private func updateSize() {
        var verticesInfos = VertexInfos(width: Float(_view.bounds.width), height: Float(_view.bounds.height))
        _verticesInfosBuffer = _device.makeBuffer(
            bytes: &verticesInfos,
            length: MemoryLayout<VertexInfos>.size,
            options: .storageModeShared
        )
    }
}
