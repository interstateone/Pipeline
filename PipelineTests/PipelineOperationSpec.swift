import Quick
import Nimble
import Result
@testable import Pipeline

let placeholderError = NSError(domain: "ca.brandonevans.Pipeline", code: 123, userInfo: nil)

class PipelineOperationSpec: QuickSpec {
    override func spec() {
        context("syncronous task") {
            context("fulfilled") {
                var operation: PipelineOperation<Int>!
                beforeEach {
                    operation = PipelineOperation { fulfill, reject, handlers in
                        fulfill(99)
                    }
                    operation.start()
                }

                it("should finish immediately") {
                    expect(operation.finished).to(beTrue())
                }
                
                it("should fulfill with value") {
                    expect(operation.output?.value).toEventually(equal(99))
                }
            }

            context("rejected") {
                var operation: PipelineOperation<Int>!
                beforeEach {
                    operation = PipelineOperation { fulfill, reject, handlers in
                        reject(placeholderError)
                    }
                    operation.start()
                }

                it("should finish immediately") {
                    expect(operation.finished).to(beTrue())
                }
                
                it("should reject with error") {
                    expect(operation.output?.error).toEventually(equal(placeholderError))
                }
            }

            context("cancelled") {
                var operation: PipelineOperation<Int>!
                var cancelFlag = false
                beforeEach {
                    operation = PipelineOperation { fulfill, reject, handlers in
                        handlers.cancelled = {
                            cancelFlag = true
                        }

                        fulfill(99)
                    }
                }

                context("before starting") {
                    beforeEach {
                        operation.cancel()
                    }

                    it("should be cancelled") {
                        expect(operation.cancelled).to(beTrue())
                    }

                    it("shouldn't call its cancel handler") {
                        expect(cancelFlag).to(beFalse())
                    }

                    it("should be finished") {
                        expect(operation.finished).to(beTrue())
                    }

                    it("shouldn't have an output value") {
                        expect(operation.output).to(beNil())
                    }
                }

                context("after finishing") {
                    beforeEach {
                        operation.start()
                        operation.cancel()
                    }

                    it("shouldn't be cancelled") {
                        expect(operation.cancelled).to(beFalse())
                    }

                    it("should be finished") {
                        expect(operation.finished).to(beTrue())
                    }

                    it("should have an output value") {
                        expect(operation.output?.value).to(equal(99))
                    }
                }
            }
        }

        context("asyncronous task") {
            context("fulfilled") {
                var operation: PipelineOperation<Int>!
                beforeEach {
                    operation = PipelineOperation { fulfill, reject, handlers in
                        background {
                            onMainAfter(0.5) {
                                fulfill(99)
                            }
                        }
                    }
                    operation.start()
                }

                it("shouldn't finish immediately") {
                    expect(operation.finished).to(beFalse())
                }

                it("should eventually finish") {
                    expect(operation.finished).toEventually(beTrue())
                }

                it("should fulfill with value") {
                    expect(operation.output?.value).toEventually(equal(99))
                }
            }

            context("rejected") {
                var operation: PipelineOperation<Int>!
                beforeEach {
                    operation = PipelineOperation { fulfill, reject, handlers in
                        background {
                            onMainAfter(0.5) {
                                reject(placeholderError)
                            }
                        }
                    }
                    operation.start()
                }

                it("shouldn't finish immediately") {
                    expect(operation.finished).to(beFalse())
                }

                it("should eventually finish") {
                    expect(operation.finished).toEventually(beTrue())
                }
                
                it("should reject with error") {
                    expect(operation.output?.error).toEventually(equal(placeholderError))
                }
            }

            context("cancelled") {
                var operation: PipelineOperation<Int>!
                var cancelFlag = false
                beforeEach {
                    operation = PipelineOperation { fulfill, reject, handlers in
                        background {
                            onMainAfter(0.5) {
                                fulfill(99)
                            }
                        }

                        handlers.cancelled = {
                            cancelFlag = true
                        }
                    }
                }

                context("before starting") {
                    beforeEach {
                        operation.cancel()
                    }

                    it("should be cancelled") {
                        expect(operation.cancelled).to(beTrue())
                    }

                    it("shouldn't call its cancel handler") {
                        expect(cancelFlag).to(beFalse())
                    }

                    it("should be finished") {
                        expect(operation.finished).to(beTrue())
                    }

                    it("shouldn't have an output value") {
                        expect(operation.output).to(beNil())
                    }
                }

                context("after starting, before finishing") {
                    beforeEach {
                        operation.start()
                        operation.cancel()
                    }

                    it("should be cancelled") {
                        expect(operation.cancelled).to(beTrue())
                    }

                    it("should call its cancel handler") {
                        expect(cancelFlag).to(beTrue())
                    }

                    it("should be finished") {
                        expect(operation.finished).to(beTrue())
                    }

                    it("shouldn't have an output value") {
                        expect(operation.output).to(beNil())
                    }
                }
            }
        }
    }
}
