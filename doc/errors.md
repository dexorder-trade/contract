| Code                | Name                          | Description                                                                                                                                        |
|---------------------|-------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| not owner           | not owner                     | The method may only be called by the owner of the contract                                                                                         |
| not upgrader        | not upgrader                  | The method may only be called by the upgrader of the contract                                                                                      |
| UNK                 | Unknown                       | A reversion with an empty error message happened                                                                                                   |
| UR                  | Unknown Route                 | The specified order route is invalid.                                                                                                              |
| OCOM                | Invalid OCO Mode              | The OCO mode provided to placeDexorder() is invalid.                                                                                               |
| OI                  | Order Index                   | The given order index is invalid.                                                                                                                  |
| COI                 | Conditional Order Index       | The index given for the conditional order is invalid. Conditional orders must be placed before they are referenced.                                |
| COS                 | Conditional Order Suitability | The conditional order must have the correct input token, amountIsInput must be true, and the conditional order cannot set its own conditionalOrder |
| TMO                 | Too Many Orders               | The maximum number of orders that can be placed at once is 255.                                                                                    |
| NO                  | Not Open                      | Execution cannot occur, because the order state is not OPEN                                                                                        |
| RL                  | Rate Limited                  | The tranche's rate limit is still in effect and execute() was called too soon                                                                      |
| TE                  | Time Early                    | Time constraint window hasn't opened yet                                                                                                           |
| TL                  | Time Late                     | Time constraint has expired the tranche                                                                                                            |
| LL                  | Lower Limit                   | Price limit constraint violation                                                                                                                   |
| LU                  | Upper Limit                   | Price limit constraint violation                                                                                                                   |
| LM                  | Line Slope                    | Line slope computation overflow (for ratio lines)                                                                                                  |
| IIA                 | Insufficient Input Amount     | Not enough input coin available in the vault (from Uniswap)                                                                                        |
| TF                  | Tranche Filled                | The tranche has no remaining amount available to execute.                                                                                          |
| Too little received | Too little received           | Uniswap v3 error when min output amount is not filled. Can happen when a limit price is very near the current price.                               |
| OVR                 | Overfilled                    | Order amount is already filled above spec. (This should never happen)                                                                              |
| UV                  | Upgrade Version               | The implementation contract address passed to upgrade() does not match the impl in VaultFactory.                                                   |
| K                   | Killed                        | The Vault or its VaultFactory has been killed. No delegated (VaultImpl) methods are available. (Withdraw/Deposit only mode)                        |
| STF                 | Safe Transfer Failure         | Error while transferring funds to the target pool                                                                                                  |
| NSL                 | Negative Slippage             | The slippage argument to a market order is negative, so the order placement was rejected.                                                          |
| WU                  | Wrapper Unimplemented         | There is no wrapper coin set on this VaultImpl.  Cannot wrap() or unwrap().                                                                        |