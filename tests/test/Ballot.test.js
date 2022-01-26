import path from "path";
import * as t from "@onflow/types"
import { emulator, init, getAccountAddress, shallPass, shallResolve, shallRevert, shallThrow } from "flow-js-testing";
import { toUFix64, getAdminAddress, getEvent } from "../src/common";

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

		// can read ballot price
		await shallResolve(async () => {
			const price = (await getPrice())[0]
			expect(price).toEqual(toUFix64(1))
		})

		// admin can set new price and emit event
		await shallResolve(async () => {
			await setPrice(toUFix64(2), Admin)
			const price = (await getPrice())[0]
			expect(price).toEqual(toUFix64(2))
		})

		// user can not set ballot price
		await shallRevert(async () => {
			await setPrice(toUFix(3), Alice)
		})

		// can not set same price
		await shallRevert(async () => {
			await setPrice(toUFix(2), Admin)
		})

		// can not set price to 0
		await shallRevert(async () => {
			await setPrice(toUFix(0), Admin)
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
			const result = await setupBallotOnAccount(Alice)
			const event = getEvent(result, 'ballotPrepared')
			const address = event.data.address
			expect(address).toBe(Alice)
		})

		// Alice can buy a ballot
		await shallResolve(async () => {
			const result = await buyBallots(Alice, 1)
			const evenData = getEvent(result, 'ballotsBought')
			expect(evenData.data.amount).toBe(1)
			expect(evenData.data.buyer).toBe(Alice)
			expect(evenData.data.price).toBe(toUFix64(1))
		})

		// can not buy 0 ballot
		await shallRevert(async () => {
			await buyBallots(Alice, 0)
		})

		// can not buy no enough token
		await shallRevert(async () => {
			await buyBallots(Alice, 1000)
		})

		// Alice can buy more ballots
		await shallResolve(async () => {
			await buyBallots(Alice, 14)
		})

		// Anyone can check Alice's ballots number
		await shallResolve(async () => {
			const ballotHolding = (await getHoldings(Alice))[0]
			expect(ballotHolding).toBe(15)
		})

		// anyone can read how many ballots sold
		await shallResolve(async () => {
			const soldAmount = (await getSoldAmount())[0]
			expect(soldAmount).toBe(15)
		})
	})
})