import path from "path";
import * as t from "@onflow/types"
import { emulator, init, getAccountAddress, shallPass, shallResolve, shallRevert } from "flow-js-testing";

import { toUFix64, getAdminAddress } from "../src/common";
import { setupCCSTokenOnAccount, mintTokenAndDistribute, getCCSTokenBalance } from "../src/CCSToken";
import { deployActivity, createActivity, getCreateConsumption, getActivityIds, getActivity, vote, closeActivity, createAirdrop } from "../src/Activity";
import { buyBallots, setupBallotOnAccount } from "../src/Ballot";
import { setupMemorialsOnAccount, getCollectionIds, getCollectionLength, getMemorial, getMemorialsSupply } from "../src/Memorials";

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

	it("people can create an activity by pass CCSToken", async () => {
		// Deploy contract
		await shallPass(deployActivity());

		// mint 100 token to alice
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

		await shallResolve(async () => {
			await mintTokenAndDistribute(args)
			const consumption = await getCreateConsumption()
			expect(consumption).toBe(toUFix64(1));
			// Alice spent token to create activity
			const result = await createActivity(Alice, 'test activity 01')
			const activityCreateEvent = result.events.find(event => event.type.includes('activityCreated'))
			expect(activityCreateEvent).not.toBe(null)
			const aliceBalance = await getCCSTokenBalance(Alice);
			expect(aliceBalance).toBe(toUFix64(sendToAliceAmount - consumption));
		});

		// can find activity id is [0]
		await shallResolve(async () => {
			const ids = await getActivityIds()
			expect(ids).toContain(0);
			expect(ids.length).toBe(1);
		})

		// new activity should have title 'test activity 01'
		await shallResolve(async () => {
			const activity = await getActivity(0)
			expect(activity.title).toBe('test activity 01');
		})
	});

	it("user can vote an activity", async () => {
		// Deploy contract
		await shallPass(deployActivity());

		// Send tokens
		const Alice = await getAccountAddress("Alice");
		const Bob = await getAccountAddress("Bob");
		const Chaier = await getAccountAddress("Chaier");
		await setupCCSTokenOnAccount(Alice)
		await setupCCSTokenOnAccount(Bob)
		await setupCCSTokenOnAccount(Chaier)
		const args =
			[
				[
					{ key: Alice, value: toUFix64(100) },
					{ key: Bob, value: toUFix64(100) },
					{ key: Chaier, value: toUFix64(100) }
				],
				t.Dictionary({ key: t.Address, value: t.UFix64 }),
			]
		await mintTokenAndDistribute(args)

		// create activity
		await createActivity(Alice, 'test activity 01')

		// Bob buy 5 ballot
		await setupBallotOnAccount(Bob);
		await buyBallots(Bob, 5);

		// Chaier buy 1 ballot
		await setupBallotOnAccount(Chaier);
		await buyBallots(Chaier, 1);

		// Bob vote for activity 0
		await shallResolve(async () => {
			await vote(Bob, 0, true)
		})

		// Chaier vote down for activity 0
		await shallResolve(async () => {
			await vote(Chaier, 0, false)
		})

		// Bob can not vote again for activity 0
		await shallRevert(async () => {
			await vote(Bob, 0, true)
		})

		// get vote result
		const result = await getActivity(0)
		expect(Object.keys(result.voteResult).length).toBe(3)
		expect(result.upVoteCount).toBe(2)
		expect(result.downVoteCount).toBe(1)
		expect(result.creator).toBe(Alice)
		expect(result.closed).toBe(false)
	})

	it("admin can close activity and mint NFT", async () => {
		// Deploy contract
		await shallPass(deployActivity());

		// Send tokens
		const Admin = await getAdminAddress();
		const Alice = await getAccountAddress("Alice");
		const Bob = await getAccountAddress("Bob");
		const Chaier = await getAccountAddress("Chaier");
		await setupCCSTokenOnAccount(Alice)
		await setupCCSTokenOnAccount(Bob)
		await setupCCSTokenOnAccount(Chaier)
		const args =
			[
				[
					{ key: Alice, value: toUFix64(100) },
					{ key: Bob, value: toUFix64(100) },
					{ key: Chaier, value: toUFix64(100) }
				],
				t.Dictionary({ key: t.Address, value: t.UFix64 }),
			]
		await mintTokenAndDistribute(args)

		// create activity and vote
		await createActivity(Alice, 'test activity 02')
		await setupBallotOnAccount(Bob);
		await setupBallotOnAccount(Chaier);
		await buyBallots(Bob, 1);
		await buyBallots(Chaier, 1);
		await vote(Bob, 0, true)
		await vote(Chaier, 0, false)

		// set memorials storage
		await setupMemorialsOnAccount(Alice)
		await setupMemorialsOnAccount(Bob)
		await setupMemorialsOnAccount(Chaier)

		// admin close Activity
		await shallResolve(async () => {
			await closeActivity(Admin, 0)
			const result = await getActivity(0)
			expect(result.closed).toBe(true)
		})

		// user vote positive should has memorials
		const AliceCollectionLength = await getCollectionLength(Alice)
		expect(AliceCollectionLength).not.toBe(0)
		const bobCollectionLength = await getCollectionLength(Bob)
		expect(bobCollectionLength).not.toBe(0)
		const chaierCollectionLength = await getCollectionLength(Chaier)
		expect(chaierCollectionLength).toBe(0)
		const memorialsSupply = await getMemorialsSupply()
		expect(memorialsSupply).toBe(2)

		const AliceCollectionIDs = await getCollectionIds(Alice)
		const AlicememorialID = AliceCollectionIDs.pop()
		const Alicememorial = await getMemorial(Alice, AlicememorialID)
		expect(Alicememorial.activityID).toBe(0)
		expect(Alicememorial.isPositive).toBe(true)
		expect(Alicememorial.owner).toBe(Alice)

		const BobCollectionIDs = await getCollectionIds(Bob)
		const BobmemorialID = BobCollectionIDs.pop()
		const Bobmemorial = await getMemorial(Bob, BobmemorialID)
		expect(Bobmemorial.activityID).toBe(0)
		expect(Bobmemorial.isPositive).toBe(true)
		expect(Bobmemorial.owner).toBe(Bob)
	})

	it("admin can airdrop special NFT to accounts", async () => {
		await deployActivity();
		const Admin = await getAdminAddress();
		const Alice = await getAccountAddress("Alice");
		const Bob = await getAccountAddress("Bob");
		await setupMemorialsOnAccount(Alice)
		await setupMemorialsOnAccount(Bob)

		await shallResolve(async () => {
			await createAirdrop(Admin, 'test airdrop', [Alice, Bob], toUFix64(5))
			const result = await getActivity(0)
			expect(result.closed).toBe(true)
		})

		// Alice and Bob should have airdrop NFT
		const AliceCollectionLength = await getCollectionLength(Alice)
		expect(AliceCollectionLength).not.toBe(0)
		const bobCollectionLength = await getCollectionLength(Bob)
		expect(bobCollectionLength).not.toBe(0)

		const AliceCollectionIDs = await getCollectionIds(Alice)
		const AlicememorialID = AliceCollectionIDs.pop()
		const Alicememorial = await getMemorial(Alice, AlicememorialID)
		expect(Alicememorial.activityID).toBe(0)
		expect(Alicememorial.owner).toBe(Alice)
		expect(Alicememorial.bonus).toBe(toUFix64(5))
		expect(Alicememorial.seriesNumber).toBe(1)
		expect(Alicememorial.circulatingCount).toBe(2)

		const BobCollectionIDs = await getCollectionIds(Bob)
		const BobmemorialID = BobCollectionIDs.pop()
		const Bobmemorial = await getMemorial(Bob, BobmemorialID)
		expect(Bobmemorial.activityID).toBe(0)
		expect(Bobmemorial.owner).toBe(Bob)
		expect(Bobmemorial.bonus).toBe(toUFix64(5))
		expect(Bobmemorial.seriesNumber).toBe(2)
	})
})

