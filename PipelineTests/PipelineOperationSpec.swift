import Quick
import Nimble
import Result
@testable import Pipeline

let background = { then in
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), then)
}

let onMainAfter: (Int64, () -> ()) -> () = { seconds, then in
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, seconds * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), then)
}

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
                
                it("should fulfill with value") {
                    expect(operation.output?.value).toEventually(equal(99))
                }
            }
            context("rejected") {

            }
        }

        context("asyncronous task") {
            context("fulfilled") {
                var operation: PipelineOperation<Int>!
                beforeEach {
                    operation = PipelineOperation { fulfill, reject in
                        background {
                            onMainAfter(3) {
                                fulfill(99)
                            }
                        }
                    }
                    operation.start()
                }
                
                it("should fulfill with value") {
                    expect(operation.output?.value).toEventually(equal(99))
                }
            }
        }
    }
}
