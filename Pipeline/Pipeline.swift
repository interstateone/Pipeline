//
//  Pipeline.swift
//  Pipeline
//
//  Created by Brandon Evans on 2015-07-16.
//  Copyright © 2015 Brandon Evans. All rights reserved.
//

import Foundation

internal enum PipelineState {
    case Ready
    case Started
    case Cancelled
}

public class Pipeline<T> {
    internal var state: PipelineState = .Ready {
        willSet {
            if state == .Cancelled {
                return
            }
        }
    }

    internal let queue: PipelineQueue

    // MARK: Initialization
    
    /**
    Creates a new Pipeline

    :param: handler Closure that returns the Pipeline's first value
    */
    public init(handler: () -> T) {
        queue = PipelineQueue(.QOS(.Default))
        let operation = PipelineOperation<T> { fulfill, reject, cancelled in
            fulfill(handler())
        }
        queue.addOperation(operation)
    }

    /**
    Creates a new Pipeline

    :param: QOS     The quality of service that the handler will be enqueued with
    :param: handler Closure that returns the Pipeline's first value
    */
    public convenience init(_ QOS: NSQualityOfService = .Default, handler: () -> T) {
        self.init(.QOS(QOS), handler: handler)
    }

    /**
    Creates a new Pipeline

    :param: queueLevel The queue level that the handler will be enqueued with
    :param: handler    Closure that returns the Pipeline's first value
    */
    public init(_ queueLevel: PipelineQueue.QueueLevel = .QOS(.Default), handler: () -> T) {
        queue = PipelineQueue(queueLevel)
        let operation = PipelineOperation { fulfill, reject, cancelled in
            fulfill(handler())
        }
        queue.addOperation(operation)
    }

    /**
    Creates a new Pipeline

    :param: QOS              The quality of service that the operation will be enqueued with
    :param: operationHandler Closure that returns a PipelineOperation that is fulfilled with the Pipeline's first value
    */
    public convenience init(_ QOS: NSQualityOfService = .Default, operationHandler: () -> PipelineOperation<T>) {
        self.init(.QOS(QOS), operationHandler: operationHandler)
    }

    /**
    Creates a new Pipeline

    :param: queueLevel       The queue level that the operation will be enqueued with
    :param: operationHandler Closure that returns a PipelineOperation that is fulfilled with the Pipeline's first value
    */
    public init(_ queueLevel: PipelineQueue.QueueLevel = .QOS(.Default), operationHandler: () -> PipelineOperation<T>) {
        queue = PipelineQueue(queueLevel)
        let operation = operationHandler()
        queue.addOperation(operation)
    }

    private init(queue: PipelineQueue, operation: PipelineOperation<T>, QOS: PipelineQueue.QueueLevel = .QOS(.Default)) {
        self.queue = queue
        queue.addOperation(operation, QOS)
    }

    // MARK: Changing state

    /**
    Starts execution of the Pipeline's operations if it's ready. If the pipeline has already been started or has been cancelled, no action will be taken.
    */
    public func start() {
        if state != .Ready {
            return
        }
        state = .Started
        queue.suspended = false
    }

    /**
    Cancels the pipeline and all it's enqueued operations.
    */
    public func cancel() {
        state = .Cancelled
        queue.cancelAllOperations()
    }

    // MARK: Success with values

    public func success<U>(successHandler handler: T -> U) -> Pipeline<U> {
        return self.success(queue, queue.queueLevel, successHandler: handler)
    }

    public func success<U>(QOS: PipelineQueue.QueueLevel, successHandler handler: T -> U) -> Pipeline<U> {
        return self.success(queue, QOS, successHandler: handler)
    }

    // Shortcut for above when using .QOS level instead of .Main
    public func success<U>(QOS: NSQualityOfService, successHandler handler: T -> U) -> Pipeline<U> {
        return self.success(queue, .QOS(QOS), successHandler: handler)
    }

    public func success<U>(queue: PipelineQueue, _ QOS: PipelineQueue.QueueLevel, successHandler handler: T -> U) -> Pipeline<U> {
        let lastOperation = queue.operations.last as! PipelineOperation<T>
        let operation = PipelineOperation<U> { fulfill, reject, handlers in
            if let output = lastOperation.output {
                switch output {
                case .Failure(let error): reject(error)
                case .Success(let output): fulfill(handler(output))
                }
            }
        }
        operation.addDependency(lastOperation)
        return Pipeline<U>(queue: self.queue, operation: operation, QOS: QOS)
    }

    // MARK: Success with operations

    public func success<U, Operation where Operation: NSOperation, Operation: Pipelinable, Operation.Value == U>(successHandler handler: T -> Operation) -> Pipeline<U> {
        return self.success(queue, queue.queueLevel, successHandler: handler)
    }

    public func success<U, Operation where Operation: NSOperation, Operation: Pipelinable, Operation.Value == U>(QOS: PipelineQueue.QueueLevel, successHandler handler: T -> Operation) -> Pipeline<U> {
        return self.success(queue, QOS, successHandler: handler)
    }

    public func success<U, Operation where Operation: NSOperation, Operation: Pipelinable, Operation.Value == U>(QOS: NSQualityOfService, successHandler handler: T -> Operation) -> Pipeline<U> {
        return self.success(queue, .QOS(QOS), successHandler: handler)
    }

    public func success<U, Operation where Operation: NSOperation, Operation: Pipelinable, Operation.Value == U>(queue: PipelineQueue, _ QOS: PipelineQueue.QueueLevel, successHandler handler: T -> Operation) -> Pipeline<U> {
        let lastOperation = queue.operations.last as! PipelineOperation<T>
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
        return Pipeline<U>(queue: self.queue, operation: operation)
    }
}
