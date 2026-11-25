# Reserve Auction

An open English auction that records the winning bid for an off-chain lot and settles ETH on-chain.

## How it works

1. The seller deploys with a digest describing the lot, a reserve in wei, and a duration in seconds.
2. Bidders submit ETH with `bid()`. An outbid bidder may call `withdraw(recipient)` independently.
3. Once the auction closes, anyone can call `settle()`. The seller receives a withdrawal credit for the winning bid.

The winner is recorded on-chain. Delivery of the lot is handled by the seller. A bid at the reserve is accepted and subsequent bids must be strictly higher.

## Build and test

Install [Foundry](https://getfoundry.sh/) and run these commands from this directory. Forge selects Solidity 0.8.36 from `foundry.toml`. The project has no third-party Solidity dependencies.

```bash
forge build
forge test -vv
forge coverage --exclude-tests
```

## Local deployment

Start a fresh `anvil` node in a separate terminal. Deploy with the first unlocked account on that local node.

```bash
export RPC_URL=http://127.0.0.1:8545
export ANVIL_ACCOUNT=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
forge create src/ReserveAuction.sol:ReserveAuction --rpc-url "$RPC_URL" --from "$ANVIL_ACCOUNT" --unlocked --broadcast --constructor-args "$(cast keccak lot-001)" 100000000000000000 3600
```

## Local example

Set `CONTRACT` to the address printed by `forge create` and keep using the same terminal.

```bash
export ETH_RPC_URL="$RPC_URL"
CONTRACT=0x... # Replace with your deployed address.
BIDDER=0x70997970C51812dc3A010C7d01b50e0d17dc79C8
cast send "$CONTRACT" 'bid()' --from "$BIDDER" --value 0.2ether --unlocked
cast rpc evm_increaseTime 3600
cast rpc evm_mine
cast send "$CONTRACT" 'settle()' --from "$ANVIL_ACCOUNT" --unlocked
cast call "$CONTRACT" 'winner()(address)'
cast send "$CONTRACT" 'withdraw(address)' "$ANVIL_ACCOUNT" --from "$ANVIL_ACCOUNT" --unlocked
```

## Test cases

Foundry reports 7 passing tests and 100% coverage on contract lines, statements, branches and functions.

- Reserve enforcement, repeat bidding, credits and the closing boundary.
- Settlement with and without bids, rejection of repeated settlement and failed credit withdrawals.
- Fuzzed consecutive bids and conservation of the escrowed ETH.
