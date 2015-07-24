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

    public func addOperation<Operation where Operation: NSOperation, Operation: Pipelinable>(operation: Operation, _ queue: QueueLevel? = nil) {
        if let queue = queue {
            switch queue {
            case .Main:
                PipelineQueue(.Main).addOperation(operation)
            case .QOS(let QOS):
                operation.qualityOfService = QOS
                internalQueue.addOperation(operation)
            }
        }
        else {
            internalQueue.addOperation(operation)
        }
    }
}

public class Pipeline {
    private let queue: PipelineQueue

    public init<U>(handler: () -> U) {
        queue = PipelineQueue(.QOS(.Default))
        let operation = PipelineOperation<U> { fulfill, reject, cancelled in
            fulfill(handler())
        }
        queue.addOperation(operation)
    }

    public convenience init<U>(_ QOS: NSQualityOfService = .Default, handler: () -> U) {
        self.init(.QOS(QOS), handler: handler)
    }

    public init<U>(_ queueLevel: PipelineQueue.QueueLevel = .QOS(.Default), handler: () -> U) {
        queue = PipelineQueue(queueLevel)
        let operation = PipelineOperation<U> { fulfill, reject, cancelled in
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
            let operation = PipelineOperation<U> { fulfill, reject, handlers in
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
    public func success<T, U, Operation where Operation: NSOperation, Operation: Pipelinable, Operation.Value == U>(successHandler handler: T -> Operation) -> Pipeline {
        return self.success(queue, queue.queueLevel, successHandler: handler)
    }

    public func success<T, U, Operation where Operation: NSOperation, Operation: Pipelinable, Operation.Value == U>(QOS: PipelineQueue.QueueLevel, successHandler handler: T -> Operation) -> Pipeline {
        return self.success(queue, QOS, successHandler: handler)
    }

    public func success<T, U, Operation where Operation: NSOperation, Operation: Pipelinable, Operation.Value == U>(QOS: NSQualityOfService, successHandler handler: T -> Operation) -> Pipeline {
        return self.success(queue, .QOS(QOS), successHandler: handler)
    }

    public func success<T, U, Operation where Operation: NSOperation, Operation: Pipelinable, Operation.Value == U>(queue: PipelineQueue, _ QOS: PipelineQueue.QueueLevel, successHandler handler: T -> Operation) -> Pipeline {
        if let lastOperation = queue.operations.last as? PipelineOperation<T> {
            var operation: PipelineOperation<U>!
            operation = PipelineOperation<U> { fulfill, reject, handlers in
                if let output = lastOperation.output {
                    switch output {
                    case .Failure(let error):
                        reject(error)
                    case .Success(let output):
                        let innerOp = handler(output)

                        let fulfillCompletion = { () -> Void in
                            if let output = innerOp.output {
                                switch output {
                                case let .Success(value):
                                    fulfill(value)
                                case let .Failure(error):
                                    reject(error)
                                }
                            }
                            reject(NSError(domain: "", code: 123, userInfo: nil))
                        }

                        // Hijack original completion block if needed
                        if let originalCompletion = innerOp.completionBlock {
                            innerOp.completionBlock = {
                                originalCompletion()
                                fulfillCompletion()
                            }
                        }
                        else {
                            innerOp.completionBlock = fulfillCompletion
                        }

                        operation.internalQueue.addOperation(innerOp, QOS)
                    }
                }
            }
            operation.addDependency(lastOperation)
            // Don't add the wrapper operation with the supplied QueueLevel because if it's .Main then it and the inner operation are on the same serial queue
            queue.addOperation(operation)
        }
        
        return self
    }
}
