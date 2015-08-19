# Pipeline

**This is a work-in-progress and might not ever be any more than an experiment.**

## A Trivial Example

```swift
// class PrintOperation: NSOperation, Pipelinable
// func fibonacci(n: Int) -> Int

let n = 15
Pipeline(.Background) {
    PipelineOperation { fulfill, _, _ in fulfill(fibonacci(n)) }
}.success { input in
    "\(n)th Fibonacci number: \(input)"
}.success(.Main) { input in
    return PrintOperation(input: input)
}.start()
```

## Definitions

### Pipeline

Encapsulates a queue and enqueuing operations onto it. Has a default queue priority and allows overriding that priority when adding operations, including specifying that an operation should run on the main queue.

### PipelineOperation

A NSOperation subclass that conforms to the Pipelinable protocol, which simply means that it has a `Result<Value, NSError>` output value. It can be fulfilled with a value, rejected with an error, or cancelled. Used internally for Pipeline, but can be useful elsewhere.

