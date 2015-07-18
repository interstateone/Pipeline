import Quick
import Nimble
import Result
@testable import Pipeline

let background = { then in
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), then)
}

let onMainAfter: (Double, () -> ()) -> () = { seconds, then in
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(seconds) * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), then)
}

let placeholderError = NSError(domain: "ca.brandonevans.Pipeline", code: 123, userInfo: nil)

class PipelineOperationSpec: QuickSpec {
    override func spec() {
        context("syncronous task") {
            context("fulfilled") {
                var operation: PipelineOperation<Int>!
                beforeEach {
                    operation = PipelineOperation { fulfill, reject in
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
                    operation = PipelineOperation { fulfill, reject in
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
                beforeEach {
                    operation = PipelineOperation { fulfill, reject in
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
                    operation = PipelineOperation { fulfill, reject in
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
                    operation = PipelineOperation { fulfill, reject in
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
                beforeEach {
                    operation = PipelineOperation { fulfill, reject in
                        background {
                            onMainAfter(0.5) {
                                fulfill(99)
                            }
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
