# Solidity Primer

* memory model has three locations: `storage`, `memory`, and `calldata`
  * `storage` is per-contract private data, the members of the contract, stored on-chain. it's very gassy to read/write to storage.
  * `memory` is transient read/write memory whose lifetime ends after the transaction completes or reverts. far less gassy than storage.
  * `calldata` is a small read-only area for function arguments. you should rarely if ever need to use this keyword.  reading from calldata takes the least gas of all.
* word size is 256 bits.  int and uint types are available for every 8-bit interval from `uint8`, `uint16`, `uint24`, ..., `uint256`.  do not use the bare `uint` even though it's a legal alias for 256.
* similarly to `uint?` types, there are value types `bytes1`, `bytes2`, ..., `bytes32` which is 256 bits. `bytes` by itself is an alias for the dynamic array `byte[]`
* do not use `string` type.  use `bytes` instead.  for reasons.
* arrays have three types: dynamic storage array, dynamic memory array, and static array.
  * all arrays in storage (contract or struct members) start as 0-length and may only be extended by `contractArray.push(item)` one at a time. remove with `pop()`. a storage array referenced inside a function as `Foo[] storage myArray = contractArray;` results in a reference to the storage area.
  * dynamic memory arrays `Foo[] memory myArray = new Foo[](length);` only this c++ style allocation is available for dynamic memory arrays, and the length must be known at creation time. you must then set each member of the array separately, in a loop.
  * static memory arrays `Foo[4] memory myArray = [foo1, foo2, foo3, foo4];` the length of the array is part of the type information, and it is not possible to cast a dynamic array to a static one or vice-versa.
* functions have two different types: views and transactions.
  * a view is read-only and may be completed instantly off-chain. its return values are immediately available to whatever client invoked the call.
  * transactions make changes to chain data.  the return values from a transaction function are not written to chain, but they are immediately useable by other code that calls into that function from the same transaction.
* Events are the way to publish queryable on-chain results. they are declared types and the `emit` keyword is used to create an event log record on-chain.
