import path from "path";
import * as t from "@onflow/types"
import { emulator, init, getAccountAddress, shallPass, shallResolve } from "flow-js-testing";

import { toUFix64 } from "../src/common";
import {
	deployCCSToken,
	getCCSTokenSupply,
	mintTokenAndDistribute,
	setupCCSTokenOnAccount,
	getCCSTokenBalance
} from "../src/CCSToken";

// We need to set timeout for a higher number, because some transactions might take up some time
jest.setTimeout(500000);

describe("CCSToken", () => {
	// Instantiate emulator and path to Cadence files
	beforeEach(async () => {
		const basePath = path.resolve(__dirname, "../../");
		const port = 7001;
		await init(basePath, { port });
		return emulator.start(port, false);
	});

	// Stop emulator, so it could be restarted
	afterEach(async () => {
		return emulator.stop();
	});

	it("shall have initialized supply field correctly", async () => {
		// Deploy contract
		await shallPass(deployCCSToken());

		await shallResolve(async () => {
			const supply = await getCCSTokenSupply();
			expect(supply).toBe(toUFix64(0));
		});
	});

	it("shall user provision account", async () => {
		// Setup
		await deployCCSToken();
		const Alice = await getAccountAddress("Alice");
		await shallPass(setupCCSTokenOnAccount(Alice));
	})

	it("admin can airdrop tokens to accounts", async () => {
		await deployCCSToken();

		const Alice = await getAccountAddress("Alice");
		await setupCCSTokenOnAccount(Alice)
		const sendToAliceAmount = 100
		const Bob = await getAccountAddress("Bob");
		await setupCCSTokenOnAccount(Bob)
		const sendToBobAmount = 50.5
		const args =
			[
				[
					{ key: Alice, value: toUFix64(sendToAliceAmount) },
					{ key: Bob, value: toUFix64(sendToBobAmount) },
				],
				t.Dictionary({ key: t.Address, value: t.UFix64 }),
			]
		await shallResolve(async () => {
			await mintTokenAndDistribute(args)
		});

		await shallResolve(async () => {
			const supply = await getCCSTokenSupply();
			const aliceBalance = await getCCSTokenBalance(Alice);
			const boBBalance = await getCCSTokenBalance(Bob);
			expect(supply).toBe(toUFix64(sendToAliceAmount + sendToBobAmount));
			expect(aliceBalance).toBe(toUFix64(sendToAliceAmount));
			expect(boBBalance).toBe(toUFix64(sendToBobAmount));
		});
	})
})