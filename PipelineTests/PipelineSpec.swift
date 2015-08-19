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

class PipelineSpec: QuickSpec {
    override func spec() {
        context("single asyncronous operation") {
            var operation: PipelineOperation<Int>!
            var pipeline: Pipeline<Int>!
            beforeEach {
                pipeline = Pipeline(.Background) {
                    PipelineOperation { fulfill, reject, handlers in
                        background {
                            onMainAfter(0.5) {
                                fulfill(42)
                            }
                        }
                    }
                }

                operation = pipeline.queue.operations.first as! PipelineOperation<Int>
            }

            it("should be in .Ready state") {
                expect(pipeline.state).to(equal(PipelineState.Ready))
            }
            
            describe("start()") {
                beforeEach {
                    pipeline.start()
                }
                
                it("should change state to .Started") {
                    expect(pipeline.state).to(equal(PipelineState.Started))
                }
            }
            
            describe("cancel()") {
                context("before starting") {
                    beforeEach {
                        pipeline.cancel()
                    }

                    it("should be cancelled") {
                        expect(pipeline.state).to(equal(PipelineState.Cancelled))
                    }

                    it("operation should be cancelled") {
                        expect(operation.cancelled).to(beTrue())
                    }

                    it("operation shouldn't have output") {
                        expect(operation.output).to(beNil())
                    }

                    it("shouldn't have any operations") {
                        expect(pipeline.queue.operations).to(beEmpty())
                    }
                }

                context("after starting") {
                    beforeEach {
                        pipeline.start()
                        pipeline.cancel()
                    }
                    
                    it("should be cancelled") {
                        expect(pipeline.state).to(equal(PipelineState.Cancelled))
                    }

                    it("operation should be cancelled") {
                        expect(operation.cancelled).to(beTrue())
                    }

                    it("operation shouldn't have output") {
                        expect(operation.output).to(beNil())
                    }

                    it("shouldn't have any operations") {
                        expect(pipeline.queue.operations).to(beEmpty())
                    }
                }

                context("after operation has finished") {
                    beforeEach {
                        pipeline.start()
                        background {
                            onMainAfter(1.0) {
                                pipeline.cancel()
                            }
                        }
                    }
                    
                    it("should be cancelled") {
                        expect(pipeline.state).toEventually(equal(PipelineState.Cancelled), timeout: 2.0)
                    }

                    it("operation shouldn't be cancelled") {
                        expect(operation.cancelled).toEventually(beFalse(), timeout: 2.0)
                    }

                    it("operation should have output") {
                        expect(operation.output?.value).toEventually(equal(42))
                    }

                    it("shouldn't have any operations") {
                        expect(pipeline.queue.operations).toEventually(beEmpty())
                    }
                }
            }
        }
    }
}
