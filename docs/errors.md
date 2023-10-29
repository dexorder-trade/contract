| Code | Name                      | Description                                                            |
|------|---------------------------|------------------------------------------------------------------------|
| OCOM | Invalid OCO Mode          | The OCO mode provided to placeOrder() is invalid.                      |
| UR   | Unknown Route             | The specified order route is invalid.                                  | 
| NO   | Not Open                  | Order status state is not OPEN                                         |
| UC   | Unknown Constraint        | The constraint specification did not have a recognized Constraint Mode |
| TE   | Too Early                 | Time constraint window hasn't opened yet                               |
| TL   | Too Late                  | Time constraint has expired the tranche                                |
| L    | Limit                     | Price limit constraint violation                                       |
| IIA  | Insufficient Input Amount | Not enough input coin available in the vault (from Uniswap)            |
| TF   | Tranche Filled            | The tranche has no remaining amount available to execute.              |
