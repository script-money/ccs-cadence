import path from "path";
import * as t from "@onflow/types"
import { emulator, init, getAccountAddress, shallPass, shallResolve, shallRevert } from "flow-js-testing";
import { toUFix64, getAdminAddress } from "../src/common";

import { deployBallot, buyBallots, getHoldings, setupBallotOnAccount, getSoldAmount, setPrice, getPrice } from "../src/Ballot";
import { setupCCSTokenOnAccount, mintTokenAndDistribute } from "../src/CCSToken";

// We need to set timeout for a higher number, because some transactions might take up some time
jest.setTimeout(500000);

describe("Activity", () => {
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

	it("ballot contract can be deployed", async () => {
		await shallPass(deployBallot());
	})

	it("ballot price can be set correct", async () => {
		await deployBallot();
		const Admin = await getAdminAddress()
		const Alice = await getAccountAddress("Alice")

		await shallResolve(async () => {
			const price = await getPrice()
			expect(price).toEqual(toUFix64(1))
		})

		await shallResolve(async () => {
			await setPrice(toUFix64(2), Admin)
			const price = await getPrice()
			expect(price).toEqual(toUFix64(2))
		})

		// another can not set ballot price
		await shallRevert(async () => {
			await setPrice(toUFix(3), Alice)
		})
	})

	it("user can buy a ballot with $CCS", async () => {
		await deployBallot();

		// mint 100 CCS token to alice
		const Alice = await getAccountAddress("Alice");
		await setupCCSTokenOnAccount(Alice)
		const sendToAliceAmount = 100
		const args =
			[
				[
					{ key: Alice, value: toUFix64(sendToAliceAmount) }
				],
				t.Dictionary({ key: t.Address, value: t.UFix64 }),
			]
		await mintTokenAndDistribute(args)

		// privision ballot storage
		await shallResolve(async () => {
			await setupBallotOnAccount(Alice)
		})

		// Alice can buy a ballot
		await shallResolve(async () => {
			await buyBallots(Alice, 1)
		})

		// Alice can buy more ballots, price is 0.0
		await shallResolve(async () => {
			await buyBallots(Alice, 14)
		})

		// Anyone can check Alice's ballots number
		await shallResolve(async () => {
			const ballotHolding = await getHoldings(Alice)
			expect(ballotHolding).toBe(15)
		})

		// anyone can read how many ballots sold
		await shallResolve(async () => {
			const soldAmount = await getSoldAmount()
			expect(soldAmount).toBe(15)
		})
	})
})