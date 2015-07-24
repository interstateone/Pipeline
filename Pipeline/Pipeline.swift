//
//  Pipeline.swift
//  Pipeline
//
//  Created by Brandon Evans on 2015-07-16.
//  Copyright © 2015 Brandon Evans. All rights reserved.
//

import Foundation

public class PipelineQueue {
    public enum QueueLevel {
        case Main
        case QOS(NSQualityOfService)
    }

    private let internalQueue: NSOperationQueue

    public let queueLevel: QueueLevel
    public var suspended = true {
        didSet {
            internalQueue.suspended = suspended
        }
    }
    public var operations: [NSOperation] {
        return internalQueue.operations
    }

    public init(_ queueLevel: QueueLevel = .QOS(.Default)) {
        self.queueLevel = queueLevel
        switch queueLevel {
        case .Main:
            internalQueue = NSOperationQueue.mainQueue()
        case .QOS(let QOS):
            internalQueue = NSOperationQueue()
            internalQueue.qualityOfService = QOS
        }
    }

    public func cancelAllOperations() {
        internalQueue.cancelAllOperations()
    }

    public func addOperation<O where O: NSOperation, O: Pipelinable>(op: O, _ queue: QueueLevel? = nil) {
        if let queue = queue {
            switch queue {
            case .Main:
                PipelineQueue(.Main).addOperation(op)
            case .QOS(let QOS):
                op.qualityOfService = QOS
                internalQueue.addOperation(op)
            }
        }
        else {
            internalQueue.addOperation(op)
        }
    }
}

public class Pipeline {
    private let queue: PipelineQueue

    public init<U>(handler: () -> U) {
        queue = PipelineQueue(.QOS(.Default))
        let operation = PipelineOperation<U> { fulfill, reject in
            fulfill(handler())
        }
        queue.addOperation(operation)
    }

    public convenience init<U>(_ QOS: NSQualityOfService = .Default, handler: () -> U) {
        self.init(.QOS(QOS), handler: handler)
    }

    public init<U>(_ queueLevel: PipelineQueue.QueueLevel = .QOS(.Default), handler: () -> U) {
        queue = PipelineQueue(queueLevel)
        let operation = PipelineOperation<U> { fulfill, reject in
            fulfill(handler())
        }
        queue.addOperation(operation)
    }

    public convenience init<U>(_ QOS: NSQualityOfService = .Default, operationHandler: () -> PipelineOperation<U>) {
        self.init(.QOS(QOS), operationHandler: operationHandler)
    }

    public init<U>(_ queueLevel: PipelineQueue.QueueLevel = .QOS(.Default), operationHandler: () -> PipelineOperation<U>) {
        queue = PipelineQueue(queueLevel)
        let operation = operationHandler()
        queue.addOperation(operation)
    }

    public func start() {
        queue.suspended = false
    }

    // Values
    public func success<T, U>(successHandler handler: T -> U) -> Pipeline {
        return self.success(queue, queue.queueLevel, successHandler: handler)
    }

    public func success<T, U>(QOS: PipelineQueue.QueueLevel, successHandler handler: T -> U) -> Pipeline {
        return self.success(queue, QOS, successHandler: handler)
    }

    // Shortcut for above when using .QOS level instead of .Main
    public func success<T, U>(QOS: NSQualityOfService, successHandler handler: T -> U) -> Pipeline {
        return self.success(queue, .QOS(QOS), successHandler: handler)
    }

    public func success<T, U>(queue: PipelineQueue, _ QOS: PipelineQueue.QueueLevel, successHandler handler: T -> U) -> Pipeline {
        if let lastOperation = queue.operations.last as? PipelineOperation<T> {
            let operation = PipelineOperation<U> { fulfill, reject in
                if let output = lastOperation.output {
                    switch output {
                    case .Failure(let error): reject(error)
                    case .Success(let output): fulfill(handler(output))
                    }
                }
            }
            operation.addDependency(lastOperation)
            queue.addOperation(operation, QOS)
        }

        return self
    }

    // Operations
    public func success<T, U>(successHandler handler: T -> PipelineOperation<U>) -> Pipeline {
        return self.success(queue, queue.queueLevel, successHandler: handler)
    }

    public func success<T, U>(QOS: PipelineQueue.QueueLevel, successHandler handler: T -> PipelineOperation<U>) -> Pipeline {
        return self.success(queue, QOS, successHandler: handler)
    }

    public func success<T, U>(QOS: NSQualityOfService, successHandler handler: T -> PipelineOperation<U>) -> Pipeline {
        return self.success(queue, .QOS(QOS), successHandler: handler)
    }

    public func success<T, U>(queue: PipelineQueue, _ QOS: PipelineQueue.QueueLevel, successHandler handler: T -> PipelineOperation<U>) -> Pipeline {
        if let lastOperation = queue.operations.last as? PipelineOperation<T> {
            var operation: PipelineOperation<U>!
            operation = PipelineOperation<U> { fulfill, reject in
                if let output = lastOperation.output {
                    switch output {
                    case .Failure(let error):
                        reject(error)
                    case .Success(let output):
                        let innerOp = handler(output)
                        innerOp.success { output in fulfill(output) }
                        operation.internalQueue.addOperation(innerOp, QOS)
                    }
                }
            }
            operation.addDependency(lastOperation)
            queue.addOperation(operation, QOS)
        }
        
        return self
    }
}
