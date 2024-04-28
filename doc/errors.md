| Code                | Name                      | Description                                                                                                          |
|---------------------|---------------------------|----------------------------------------------------------------------------------------------------------------------|
| UNK                 | Unknown                   | A reversion with an empty error message happened                                                                     |
| OCOM                | Invalid OCO Mode          | The OCO mode provided to placeDexorder() is invalid.                                                                    |
| UR                  | Unknown Route             | The specified order route is invalid.                                                                                | 
| NO                  | Not Open                  | Order status state is not OPEN                                                                                       |
| TE                  | Too Early                 | Time constraint window hasn't opened yet                                                                             |
| TL                  | Too Late                  | Time constraint has expired the tranche                                                                              |
| LL                  | Lower Limit               | Price limit constraint violation                                                                                     |
| LU                  | Upper Limit               | Price limit constraint violation                                                                                     |
| IIA                 | Insufficient Input Amount | Not enough input coin available in the vault (from Uniswap)                                                          |
| TF                  | Tranche Filled            | The tranche has no remaining amount available to execute.                                                            |
| Too little received | Too little received       | Uniswap v3 error when min output amount is not filled. Can happen when a limit price is very near the current price. |
| OVR                 | Overfilled                | Order amount is already filled above spec. (This should never happen)                                                |
