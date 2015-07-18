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

private enum OperationState {
    case Ready
    case Executing
    case Finished
    case Cancelled
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

    // MARK: State Management

    class func keyPathsForValuesAffectingIsReady() -> Set<NSObject> {
        return ["state"]
    }

    class func keyPathsForValuesAffectingIsExecuting() -> Set<NSObject> {
        return ["state"]
    }

    class func keyPathsForValuesAffectingIsFinished() -> Set<NSObject> {
        return ["state"]
    }

    class func keyPathsForValuesAffectingIsCancelled() -> Set<NSObject> {
        return ["state"]
    }

    private var _state = OperationState.Ready
    private var state: OperationState {
        get {
            return _state
        }

        set(newState) {
            willChangeValueForKey("state")

            switch (_state, newState) {
                case (.Cancelled, _):
                    break // cannot leave the cancelled state
                case (.Finished, _):
                    break // cannot leave the finished state
                default:
                    assert(_state != newState, "Performing invalid cyclic state transition.")
                    _state = newState
            }

            didChangeValueForKey("state")
        }
    }

    public override var ready: Bool {
        switch state {
            case .Ready:
                return super.ready
            default:
                return false
        }
    }

    public override var executing: Bool {
        return state == .Executing
    }

    public override var finished: Bool {
        return state == .Finished || state == .Cancelled
    }

    public override var cancelled: Bool {
        return state == .Cancelled
    }

    // MARK: Initializers

    public init(task: (Fulfill, Reject) -> Void) {
        self.task = task
        super.init()
    }

    public init(value: T) {
        self.output = .Success(value)
        super.init()
    }

    // MARK: Execution

    public override final func start() {
        state = .Executing
        main()
    }

    public override final func main() {
        internalQueue.suspended = false
        if let task = self.task {
            task(fulfill, reject)
        }
    }

    public override final func cancel() {
        internalQueue.cancelAllOperations()
        state = .Cancelled
        super.cancel()
    }

    private func fulfill(output: T) {
        self.output = .Success(output)
        state = .Finished
    }

    private func reject(error: NSError) {
        self.output = .Failure(error)
        state = .Finished
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
