# ccs-cadence

The main logic is

1. creator spend tokens to create an activity
2. other users spend tokens to buy ballots then spend ballot to vote activities
3. admin close activity and mint NFT to voter who vote at right side, this is automatic task at server
4. NFT can increase user voting power

   ps: all useful data will emit by event and sync to server database

## how to run unit test

1. `brew install flow-cli` (if flow-cli not install)
2. `cd tests && yarn`
3. `yarn test`

## how to run local dev environment

1. `flow emulator`
2. open a new terminal
3. `flow project deploy` (maybe need modify emulator-account's key in ./flow.json to servicePrivKey which find the emulator output)

## how to deploy testnet

1. `cp .env.example .env` and fill your key info
2. deploy use `flow project deploy -n testnet`
3. (redeploy) run `sh remove.sh`, then rewrite all path in contract's init(), for example, replace `self.ActivityStoragePath = /storage/ActivitiesCollection_0` to `self.ActivityStoragePath = /storage/ActivitiesCollection_1`, than run 2.
4. check deploy result at *https://flow-view-source.com/testnet/account/[contract_address]*
5. use `flow keys generate` and `flow transactions send ./transactions/account/add_keys.cdc [PK] -n testnet --signer testnet-account` for server key rotation sign.
