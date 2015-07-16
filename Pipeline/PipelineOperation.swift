//
//  PipelineOperation.swift
//  Pipeline
//
//  Created by Brandon Evans on 2015-07-16.
//  Copyright © 2015 Brandon Evans. All rights reserved.
//

import Foundation
import Result

public protocol Pipelinable: class {
    typealias T
    var output: Result<T, NSError>? { get set }
}

public class PipelineOperation<T>: NSOperation, Pipelinable {
    public typealias Fulfill = T -> Void
    public typealias Reject = NSError -> Void

    public var output: Result<T, NSError>?

    private var task: ((Fulfill, Reject) -> Void)?
    public let internalQueue: PipelineQueue = {
        let q = PipelineQueue()
        q.suspended = true
        return q
    }()

    public init(task: (Fulfill, Reject) -> Void) {
        self.task = task
        super.init()
    }

    public init(value: T) {
        self.output = .Success(value)
        super.init()
    }

    public override func main() {
        internalQueue.suspended = false
        if let task = self.task {
            task({ output in
                self.output = .Success(output)
                }, { error in
                    self.output = .Failure(error)
            })
        }
    }

    public override func cancel() {
        internalQueue.cancelAllOperations()
        super.cancel()
    }

    // map
    public func success<U>(successHandler handler: T -> U) -> PipelineOperation<U> {
        let next = PipelineOperation<U> { fulfill, reject in
            if let output = self.output {
                switch output {
                case .Failure(let error): reject(error)
                case .Success(let output): fulfill(handler(output))
                }
            }
        }
        next.addDependency(self)
        internalQueue.addOperation(next)
        return next
    }

    // flatMap
    public func success<U>(successHandler handler: T -> PipelineOperation<U>) -> PipelineOperation<U> {
        var next: PipelineOperation<U>!
        next = PipelineOperation<U> { fulfill, reject in
            if let output = self.output {
                switch output {
                case .Failure(let error):
                    reject(error)
                case .Success(let output):
                    let innerOp = handler(output)
                    innerOp.success { output in fulfill(output) }
                    next.internalQueue.addOperation(innerOp)
                }
            }
        }
        next.addDependency(self)
        internalQueue.addOperation(next)
        return next
    }
}
