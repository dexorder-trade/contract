| Code                 | Name                      | Description                                                                                                          |
|----------------------|---------------------------|----------------------------------------------------------------------------------------------------------------------|
| OCOM                 | Invalid OCO Mode          | The OCO mode provided to placeOrder() is invalid.                                                                    |
| UR                   | Unknown Route             | The specified order route is invalid.                                                                                | 
| NO                   | Not Open                  | Order status state is not OPEN                                                                                       |
| UC                   | Unknown Constraint        | The constraint specification did not have a recognized Constraint Mode                                               |
| TE                   | Too Early                 | Time constraint window hasn't opened yet                                                                             |
| TL                   | Too Late                  | Time constraint has expired the tranche                                                                              |
| L                    | Limit                     | Price limit constraint violation                                                                                     |
| IIA                  | Insufficient Input Amount | Not enough input coin available in the vault (from Uniswap)                                                          |
| TF                   | Tranche Filled            | The tranche has no remaining amount available to execute.                                                            |
| Too little received  | Too little received       | Uniswap v3 error when min output amount is not filled. Can happen when a limit price is very near the current price. |
