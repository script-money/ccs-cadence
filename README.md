# ccs-cadence

## how to run unit test

1. `brew install flow-cli` (if flow-cli not install)
2. `cd tests && yarn`
3. `yarn test`

## how to run local dev environment

1. `flow emulator`
2. open a new terminal
3. `flow project deploy` (maybe need modify emulator-account's key in ./flow.json to servicePrivKey which find the emulator output)
