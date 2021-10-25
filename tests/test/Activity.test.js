import path from "path";
import * as t from "@onflow/types"
import { emulator, init, getAccountAddress, shallPass, shallResolve, shallRevert } from "flow-js-testing";
import { toUFix64, getAdminAddress, getEvent, getEvents } from "../src/common";
import { setupCCSTokenOnAccount, mintTokenAndDistribute, getCCSTokenBalance } from "../src/CCSToken";
import { deployActivity, createActivity, getCreateConsumption, updateCreateConsumption, getActivityIds, getActivity, vote, closeActivity, createAirdrop, getRewardParams, updateRewardParams, createNewAdmin } from "../src/Activity";
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

		// mint tokens to users
		const Alice = await getAccountAddress("Alice");
		const Bob = await getAccountAddress("Bob");
		await setupCCSTokenOnAccount(Alice)
		await setupCCSTokenOnAccount(Bob)
		const sendToAliceAmount = 100
		const sendToBobAmount = 99
		const args =
			[
				[
					{ key: Alice, value: toUFix64(sendToAliceAmount) },
					{ key: Bob, value: toUFix64(sendToBobAmount) }
				],
				t.Dictionary({ key: t.Address, value: t.UFix64 }),
			]

		await shallResolve(async () => {
			await mintTokenAndDistribute(args)
			// get create comsuption
			const consumption = await getCreateConsumption()
			expect(consumption).toBe(toUFix64(100));
			// Alice spent token to create activity
			const result = await createActivity(Alice, 'test activity 01')
			const activityCreateEvent = getEvent(result, 'activityCreated')
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

		// if not enough CCS balance, should throw error
		try {
			await createActivity(Bob, 'test activity 02')
		} catch (error) {
			expect(error.includes('Amount withdrawn must be less than or equal than the balance of the Vault')).toBe(true)
		}

	});


	it("user can vote an activity", async () => {
		// Deploy contract
		await shallPass(deployActivity());

		// Send token to users
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
			const result = await vote(Bob, 0, true)
			const activityVotedEvent = getEvent(result, 'activityVoted')
			expect(activityVotedEvent).not.toBe(null)
			const eventData = activityVotedEvent.data
			expect(eventData.id).toBe(0)
			expect(eventData.voter).toBe(Bob)
			expect(eventData.isUpVote).toBe(true)
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

		// user cannot close activity
		await shallRevert(async () => {
			await closeActivity(Alice, 0)
		})

		// admin close activity and emit events
		await shallResolve(async () => {
			const result = await closeActivity(Admin, 0)
			const activityClosedEvent = getEvent(result, 'activityClosed')
			expect(activityClosedEvent).not.toBe(null)
			const eventData = activityClosedEvent.data
			expect(eventData.id).toBe(0)
			expect(eventData.bonus).toBe(toUFix64(1))
			expect(eventData.mintPositive).toBe(true)
			expect(eventData.voteResult).toMatchObject({
				[Alice]: true,
				[Bob]: true,
				[Chaier]: false
			})

			const mintNFTEvents = getEvents(result, 'memorialMinted')
			expect(mintNFTEvents.length).toBe(2)
			const [nft1, nft2] = mintNFTEvents
			expect(nft1.data.reciever).toBe(Alice)

			const aliceIds = await getCollectionIds(Alice)
			expect(aliceIds.includes(nft1.data.memorialId)).toBe(true)
			expect(nft1.data.memorialId).toBe(1)
			const depositEvents = getEvents(result, 'Deposit')
			expect(depositEvents.length).toBe(2)
			const [nftToAlice, nftToBob] = depositEvents
			expect(aliceIds.includes(nftToAlice.data.id)).toBe(true)
			expect(nft1.data.seriesNumber).toBe(1)
			expect(nft1.data.circulatingCount).toBe(2)
			expect(nft1.data.activityID).toBe(0)
			expect(nft1.data.isPositive).toBe(true)
			expect(nft1.data.bonus).toBe(toUFix64(1))

			expect(nft2.data.reciever).toBe(Bob)
			const bobIds = await getCollectionIds(Bob)
			expect(bobIds.includes(nft2.data.memorialId)).toBe(true)
			expect(nft2.data.memorialId).toBe(2)
			expect(bobIds.includes(nftToBob.data.id)).toBe(true)
			expect(nft2.data.seriesNumber).toBe(2)
			expect(nft2.data.circulatingCount).toBe(2)
			expect(nft2.data.activityID).toBe(0)
			expect(nft2.data.isPositive).toBe(true)
			expect(nft2.data.bonus).toBe(toUFix64(1))

			const result2 = await getActivity(0)
			expect(result2.closed).toBe(true)
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

		// can get memorials information
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

		// user can not create airdrop
		await shallRevert(async () => {
			await createAirdrop(Alice, 'test airdrop 2', [Bob], toUFix64(5))
		})

		// admin can create airdrop
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


	it("admin can set reward params, user can't", async () => {
		await deployActivity();
		const Admin = await getAdminAddress();
		const Alice = await getAccountAddress("Alice");
		const rewardParams = await getRewardParams()
		expect(rewardParams.maxRatio).toBe(toUFix64(5))
		expect(rewardParams.minRatio).toBe(toUFix64(1))
		expect(rewardParams.averageRatio).toBe(toUFix64(1.5))
		expect(rewardParams.asymmetry).toBe(toUFix64(2))

		await shallResolve(async () => {
			const result = await updateRewardParams(Admin, {
				maxRatio: toUFix64(6),
				minRatio: toUFix64(1.1),
				averageRatio: toUFix64(1.3),
				asymmetry: toUFix64(2.0)
			})
			const event = getEvent(result, 'rewardParameterUpdated')
			const newParams = event.data.newParams
			expect(newParams.maxRatio).toBe(toUFix64(6))
			expect(newParams.minRatio).toBe(toUFix64(1.1))
			expect(newParams.averageRatio).toBe(toUFix64(1.3))
			expect(newParams.asymmetry).toBe(toUFix64(2.0))
		})

		const rewardParams2 = await getRewardParams()
		expect(rewardParams2.maxRatio).toBe(toUFix64(6))
		expect(rewardParams2.minRatio).toBe(toUFix64(1.1))
		expect(rewardParams2.averageRatio).toBe(toUFix64(1.3))
		expect(rewardParams2.asymmetry).toBe(toUFix64(2))

		await shallRevert(async () => {
			await updateRewardParams(Alice, {
				maxRatio: toUFix64(10),
				minRatio: toUFix64(1.2),
				averageRatio: toUFix64(1.3),
				asymmetry: toUFix64(2.0)
			})
		})

		// new.minRatio >= 1.0: "minRatio should gte 1.0"
		await shallRevert(async () => {
			await updateRewardParams(Admin, {
				maxRatio: toUFix64(6),
				minRatio: toUFix64(0.9),
				averageRatio: toUFix64(1.3),
				asymmetry: toUFix64(2.0)
			})
		})

		// new.maxRatio > new.minRatio: "maxRatio should greater than minRatio"
		await shallRevert(async () => {
			await updateRewardParams(Admin, {
				maxRatio: toUFix64(1.09),
				minRatio: toUFix64(1.1),
				averageRatio: toUFix64(1.3),
				asymmetry: toUFix64(2.0)
			})
		})

		// new.averageRatio > new.minRatio: "averageRatio should gt minRatio"
		await shallRevert(async () => {
			await updateRewardParams(Admin, {
				maxRatio: toUFix64(6),
				minRatio: toUFix64(1.1),
				averageRatio: toUFix64(1.09),
				asymmetry: toUFix64(2.0)
			})
		})

		// new.averageRatio < new.maxRatio: "averageRatio should lt maxRatio"
		await shallRevert(async () => {
			await updateRewardParams(Admin, {
				maxRatio: toUFix64(6),
				minRatio: toUFix64(1.1),
				averageRatio: toUFix64(6.5),
				asymmetry: toUFix64(2.0)
			})
		})

		// new.asymmetry > 0.0: "asymmetry should greater than 0"
		await shallRevert(async () => {
			await updateRewardParams(Admin, {
				maxRatio: toUFix64(6),
				minRatio: toUFix64(1.1),
				averageRatio: toUFix64(1.3),
				asymmetry: toUFix64(0.0)
			})
		})

	})


	it("admin can change activity create comsuption, user can't", async () => {
		await deployActivity();
		const Admin = await getAdminAddress();
		const Alice = await getAccountAddress("Alice");
		await shallRevert(async () => {
			await updateCreateConsumption(Alice, toUFix64(2.0))
		})

		await shallResolve(async () => {
			const result = await updateCreateConsumption(Admin, toUFix64(3.0))
			const consumptionUpdatedEvent = getEvent(result, 'consumptionUpdated')
			expect(consumptionUpdatedEvent).not.toBe(null)
			const eventData = consumptionUpdatedEvent.data
			expect(eventData.newPrice).toBe(toUFix64(3.0))
		})
	})

	it("admin can create new activity admin", async () => {
		await deployActivity();
		const Admin = await getAdminAddress();
		const Alice = await getAccountAddress("Alice");
		await setupMemorialsOnAccount(Alice)

		await shallResolve(async () => {
			await createNewAdmin(Alice, Admin)
		})

		// Alice can create airdrop now
		await shallResolve(async () => {
			await createAirdrop(Alice, 'test airdrop', [Alice], toUFix64(5))
			const result = await getActivity(0)
			expect(result.closed).toBe(true)
		})
	})
})
