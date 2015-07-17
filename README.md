# Pipeline

Easily compose NSOperations linearly.

**This is a work-in-progress and might not ever be any more than an experiment.**

## A Trivial Example

```swift
let n = 15
Pipeline(.Background) {
    PipelineOperation { fulfill, reject in fulfill(fibonacci(n)) }
}.success { (input: Int) in
    "\(n)th Fibonacci number: \(input)"
}.success(.Main) { (input: String) -> PipelineOperation<Void> in
    return printOperation(input)
}.start()
```

## Why

I watched Dave DeLong's [impressive 2015 WWDC presentation](https://developer.apple.com/videos/wwdc/2015/?id=226) on NSOperations and looked at the demo project and thought it was _really cool_ what could be done on top of the stock classes, but I wasn't convinced of the object-orientedness and how that might make it more difficult to use in specific situations. Apple themselves suggest using the highest-level API available until you hit performance bottlenecks, and yet for some reason I don't think NSOperations are most people's first choice. The API is the highest-level provided, but it can also require a lot of code to use (subclassing) and the encapsulation of both the operation and the data makes it difficult to compose operations linearly without sharing some state. 

I've used PromiseKit and SwiftTask before, and they're both great at what they do. PromiseKit uses GCD but doesn't allow cancellation (not wrongly either, I think), and SwiftTask has some thread-safety considerations but doesn't enqueue or dispatch any work itself. So some of the power of NSOperations (cancellation, its state machine, queue priority, etc.) ends up missing or re-implemented with these libraries. I wanted to see what a high-level API similar to these looked and worked like when built on top of NSOperation. Can NSOperation be used for quick, local as well as app-wide composition? I don't know if I'm really solving these problems or just hand-waving while wrapping them up in a slightly different paradigm, so it's an experiment. :smile:

## Definitions

### Pipeline

Encapsulates a queue and enqueuing operations onto it. Has a default queue priority and allows overriding that priority when adding operations. Also allows specifying that an operation should be run on the main queue.

### Pipeline Operation

A NSOperation subclass that conforms to the Pipelinable protocol, which simply means that it has a `Result<T, NSError>` output value. It can be fulfilled with a value, rejected with an error, or cancelled.

## To Do

- [ ] Handle asyncronous tasks correctly
- [ ] Add cancellation ability
- [ ] Clarify queue priority and QOS in pipeline API
- [ ] Allow providing a NSOperationQueue when initializing a PipelineQueue
- [ ] ...

## Questions

Can Pipeline be written to consume any NSOperation that conforms to Pipelinable instead of just PipelineOperations?
