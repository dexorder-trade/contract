# General Design

Creating a separate contract for each user address allows users to deposit coins into their "account" using standard ERC20 sends without extra approvals.  Withdrawals require a contract call, but again no approval step.  Furthermore, this clarifies the no-custody nature of the setup, since DexOrder never has any claim to ownership of the user's contract.  Of course this costs extra gas up front to create the contract for the user, but on L2's it should be minimal.  What about ETH?  Hmmm...  The alternative is to have a single contract which keeps an accounting of everyone's everything.  Deposits would require approvals and a contract call.  Using separate vaults will be an easier, more secure experience for frequent traders who are more likely to be our users rather than casual, occasional traders.


