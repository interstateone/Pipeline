//
//  PipelineTests.swift
//  PipelineTests
//
//  Created by Brandon Evans on 2015-07-16.
//  Copyright © 2015 Brandon Evans. All rights reserved.
//

import Quick
import Nimble
@testable import Pipeline

func fibonacci(n: Int) -> Int {
    switch n {
    case 0: return 0
    case 1: return 1
    default: return fibonacci(n - 1) + fibonacci(n - 2)
    }
}

class PipelineSpec: QuickSpec {
    override func spec() {
        let printOperation: (String) -> PipelineOperation<Void> = { input in
            return PipelineOperation { fulfill, reject in
                print(input)
                fulfill(())
            }
        }

        let n = 15
        Pipeline(.Background) {
            PipelineOperation { fulfill, reject in fulfill(fibonacci(n)) }
        }.success { (input: Int) in
            "\(n)th Fibonacci number: \(input)"
        }.success(.Main) { (input: String) -> PipelineOperation<Void> in
            return printOperation(input)
        }.start()
    }
}
