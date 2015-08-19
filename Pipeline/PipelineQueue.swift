//
//  PipelineQueue.swift
//  Pipeline
//
//  Created by Brandon Evans on 2015-07-23.
//  Copyright © 2015 Brandon Evans. All rights reserved.
//

import Foundation

public class PipelineQueue {
    public enum QueueLevel {
        case Main
        case QOS(NSQualityOfService)
    }

    private let internalQueue: NSOperationQueue
    private var allOperations: [NSOperation] = []

    internal let queueLevel: QueueLevel
    internal var suspended = true {
        didSet {
            internalQueue.suspended = suspended
        }
    }
    internal var operations: [NSOperation] {
        return allOperations.filter { !$0.finished }
    }

    internal init(_ queueLevel: QueueLevel = .QOS(.Default)) {
        self.queueLevel = queueLevel
        switch queueLevel {
        case .Main:
            internalQueue = NSOperationQueue.mainQueue()
        case .QOS(let QOS):
            internalQueue = NSOperationQueue()
            internalQueue.qualityOfService = QOS
        }
    }

    internal init(_ queue: NSOperationQueue) {
        queueLevel = .QOS(queue.qualityOfService)
        internalQueue = queue
    }

    internal func cancelAllOperations() {
        for operation in allOperations {
            operation.cancel()
        }
        allOperations = []
    }

    internal func addOperation<Operation where Operation: NSOperation, Operation: Pipelinable>(operation: Operation, _ queue: QueueLevel? = nil) {
        allOperations.append(operation)

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
