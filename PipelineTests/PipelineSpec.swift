//
//  PipelineTests.swift
//  PipelineTests
//
//  Created by Brandon Evans on 2015-07-16.
//  Copyright © 2015 Brandon Evans. All rights reserved.
//

import Quick
import Nimble
import Result
@testable import Pipeline

func fibonacci(n: Int) -> Int {
    switch n {
    case 0: return 0
    case 1: return 1
    default: return fibonacci(n - 1) + fibonacci(n - 2)
    }
}

class PrintOperation: NSOperation, Pipelinable {
    typealias Value = Void
    var output: Result<Value, NSError>?
    var input: String

    init(input: String) {
        self.input = input
    }

    override func main() {
        print(input)
        output = .Success()
    }
}

class PipelineSpec: QuickSpec {
    override func spec() {
        let n = 15
        Pipeline(.Background) {
            PipelineOperation { fulfill, reject, handlers in fulfill(fibonacci(n)) }
        }.success { (input: Int) in
            "\(n)th Fibonacci number: \(input)"
        }.success(.Main) { (input: String) -> PrintOperation in
            return PrintOperation(input: input)
        }.start()
    }
}
