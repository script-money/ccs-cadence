# ccs-cadence

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
3. (redeploy) run `sh remove.sh`, then rewrite all path in contract's init(), for example, replace `self.ActivityStoragePath = /storage/ActivitiesCollection_01` to `self.ActivityStoragePath = /storage/ActivitiesCollection_02`, than run 2.
4. check deploy result at *https://flow-view-source.com/testnet/account/[contract_address]*
