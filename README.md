# Pipeline

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

## Definitions

### Pipeline

Encapsulates a queue and enqueuing operations onto it. Has a default queue priority and allows overriding that priority when adding operations. Also allows specifying that an operation should be run on the main queue.

### Pipeline Operation

A NSOperation subclass that conforms to the Pipelinable protocol, which simply means that it has a `Result<T, NSError>` output value. It can be fulfilled with a value, rejected with an error, or cancelled.

## To Do

- [ ] Add cancellation ability
- [ ] Clarify queue priority and QOS in pipeline API
- [ ] Allow providing a NSOperationQueue when initializing a PipelineQueue
- [ ] ...
