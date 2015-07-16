//
//  Pipeline.swift
//  Pipeline
//
//  Created by Brandon Evans on 2015-07-16.
//  Copyright © 2015 Brandon Evans. All rights reserved.
//

import Foundation

public class PipelineQueue {
    public enum Queue {
        case Main
        case QOS(NSQualityOfService)
    }

    private let q: NSOperationQueue

    public let queue: Queue
    public var suspended = true {
        didSet {
            q.suspended = suspended
        }
    }
    public var operations: [NSOperation] {
        return q.operations
    }

    public init(_ queue: Queue = .QOS(.Default)) {
        self.queue = queue
        switch queue {
        case .Main:
            q = NSOperationQueue.mainQueue()
        case .QOS(let QOS):
            q = NSOperationQueue()
            q.qualityOfService = QOS
        }
    }

    public func cancelAllOperations() {
        q.cancelAllOperations()
    }

    public func addOperation<O where O: NSOperation, O: Pipelinable>(op: O, _ queue: Queue? = nil) {
        if let queue = queue {
            switch queue {
            case .Main:
                PipelineQueue(.Main).addOperation(op)
            case .QOS(let QOS):
                op.qualityOfService = QOS
                q.addOperation(op)
            }
        }
        else {
            q.addOperation(op)
        }
    }
}

public class Pipeline {
    private let q: PipelineQueue

    public init<U>(handler: () -> U) {
        q = PipelineQueue(.QOS(.Default))
        let operation = PipelineOperation<U> { fulfill, reject in
            fulfill(handler())
        }
        q.addOperation(operation)
    }

    public init<U>(_ QOS: NSQualityOfService = .Default, handler: () -> U) {
        q = PipelineQueue(.QOS(QOS))
        let operation = PipelineOperation<U> { fulfill, reject in
            fulfill(handler())
        }
        q.addOperation(operation)
    }

    public init<U>(_ QOS: NSQualityOfService = .Default, operationHandler: () -> PipelineOperation<U>) {
        q = PipelineQueue(.QOS(QOS))
        let operation = operationHandler()
        q.addOperation(operation)
    }

    public func start() {
        q.suspended = false
    }

    // Values
    public func success<T, U>(successHandler handler: T -> U) -> Pipeline {
        return self.success(q, q.queue, successHandler: handler)
    }

    public func success<T, U>(QOS: PipelineQueue.Queue, successHandler handler: T -> U) -> Pipeline {
        return self.success(q, QOS, successHandler: handler)
    }

    public func success<T, U>(QOS: NSQualityOfService, successHandler handler: T -> U) -> Pipeline {
        return self.success(q, .QOS(QOS), successHandler: handler)
    }

    public func success<T, U>(queue: PipelineQueue, _ QOS: PipelineQueue.Queue, successHandler handler: T -> U) -> Pipeline {
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
        return self.success(q, q.queue, successHandler: handler)
    }

    public func success<T, U>(QOS: PipelineQueue.Queue, successHandler handler: T -> PipelineOperation<U>) -> Pipeline {
        return self.success(q, QOS, successHandler: handler)
    }

    public func success<T, U>(QOS: NSQualityOfService, successHandler handler: T -> PipelineOperation<U>) -> Pipeline {
        return self.success(q, .QOS(QOS), successHandler: handler)
    }

    public func success<T, U>(queue: PipelineQueue, _ QOS: PipelineQueue.Queue, successHandler handler: T -> PipelineOperation<U>) -> Pipeline {
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
