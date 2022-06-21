import path from "path";
import * as t from "@onflow/types"
import { emulator, init, getAccountAddress, shallPass, shallResolve, shallRevert } from "flow-js-testing";
import { toUFix64, getAdminAddress, getEvent, getEvents } from "../src/common";
import { setupCCSTokenOnAccount, mintTokenAndDistribute, getCCSTokenBalance } from "../src/CCSToken";
import {
	deployActivity, createActivity, getCreateConsumption, updateCreateConsumption, getActivityIds,
	getActivity, vote, closeActivity, getRewardParams, updateRewardParams,
	createNewModerator, batchMintMemorials, createAirdropActivity
} from "../src/Activity";
import { buyBallots, setupBallotOnAccount } from "../src/Ballot";
import { setupMemorialsOnAccount, getCollectionIds, getCollectionLength, getMemorial, getMemorialsSupply } from "../src/Memorials";

// We need to set timeout for a higher number, because some transactions might take up some time
jest.setTimeout(500000);

describe("Activity", () => {
	// Instantiate emulator and path to Cadence files
	beforeEach(async () => {
		const basePath = path.resolve(__dirname, "../../");
		const port = 8080;
		await init(basePath, { port });
		await emulator.start(port, false);
	});

	// Stop emulator, so it could be restarted
	afterEach(async () => {
		await emulator.stop();
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

		await mintTokenAndDistribute(args)
		const [consumption] = await shallResolve(getCreateConsumption())
		expect(consumption).toBe(toUFix64(100));
		// Alice spent token to create activity
		const [result] = await shallResolve(createActivity(Alice, 'test activity 01'))
		const activityCreateEvent = getEvent(result, 'activityCreated')
		expect(activityCreateEvent).not.toBe(null)
		const aliceBalance = (await getCCSTokenBalance(Alice))[0]
		expect(aliceBalance).toBe(toUFix64(sendToAliceAmount - consumption));

		// can find activity id is [0]
		const [ids] = await shallResolve(getActivityIds())
		expect(ids).toContain(0);
		expect(ids.length).toBe(1);

		// new activity should have title 'test activity 01'
		const [activity] = await shallResolve(getActivity(0))
		expect(activity.title).toBe('test activity 01');


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
		const [voteResult] = await shallResolve(vote(Bob, 0, true))
		const activityVotedEvent = getEvent(voteResult, 'activityVoted')
		expect(activityVotedEvent).not.toBe(null)
		const eventData = activityVotedEvent.data
		expect(eventData.id).toBe(0)
		expect(eventData.voter).toBe(Bob)
		expect(eventData.isUpVote).toBe(true)


		// Chaier vote down for activity 0
		await shallResolve(vote(Chaier, 0, false))

		// Bob can not vote again for activity 0
		await shallRevert(vote(Bob, 0, true))

		// get vote result
		const result = (await getActivity(0))[0]
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
		const David = await getAccountAddress("David");
		await setupCCSTokenOnAccount(Alice)
		await setupCCSTokenOnAccount(Bob)
		await setupCCSTokenOnAccount(Chaier)
		await setupCCSTokenOnAccount(David)
		const args =
			[
				[
					{ key: Alice, value: toUFix64(100) },
					{ key: Bob, value: toUFix64(100) },
					{ key: Chaier, value: toUFix64(100) },
					{ key: David, value: toUFix64(100) }
				],
				t.Dictionary({ key: t.Address, value: t.UFix64 }),
			]
		await mintTokenAndDistribute(args)

		// create activity and vote
		await createActivity(Alice, 'test activity 02')
		await setupBallotOnAccount(Bob);
		await setupBallotOnAccount(Chaier);
		await setupBallotOnAccount(David);
		await buyBallots(Bob, 1);
		await buyBallots(Chaier, 1);
		await buyBallots(David, 1);
		await vote(Bob, 0, true)
		await vote(Chaier, 0, false)
		await vote(David, 0, true)

		// set memorials storage
		await setupMemorialsOnAccount(Alice)
		await setupMemorialsOnAccount(Bob)
		await setupMemorialsOnAccount(Chaier)
		await setupMemorialsOnAccount(David)

		// user cannot close activity
		await shallRevert(closeActivity(Alice, 0))

		// admin close activity and emit events
		const [result] = await shallResolve(closeActivity(Admin, 0))
		const activityClosedEvent = getEvent(result, 'activityClosed')
		expect(activityClosedEvent).not.toBe(null)
		const eventData = activityClosedEvent.data
		expect(eventData.id).toBe(0)
		const voteDict1 = { [Alice]: true, [Bob]: true }
		const [result1] = await shallResolve(batchMintMemorials(Admin, 0, true, voteDict1))
		const mintNFTEvents = getEvents(result1, 'memorialMinted')
		expect(mintNFTEvents.length).toBe(2)
		const [nft1, nft2] = mintNFTEvents
		expect(nft1.data.reciever).toBe(Alice)

		const voteDict2 = { [Chaier]: false, [David]: true }
		const [result2] = await shallResolve(batchMintMemorials(Admin, 0, true, voteDict2, 3))
		const mintNFTEvents2 = getEvents(result2, 'memorialMinted')
		expect(mintNFTEvents2.length).toBe(1)
		const [nft3] = mintNFTEvents2
		expect(nft3.data.reciever).toBe(David)

		const [aliceIds] = await shallResolve(getCollectionIds(Alice))
		expect(aliceIds.includes(nft1.data.memorialId)).toBe(true)
		expect(nft1.data.memorialId).toBe(1)
		const depositEvents = getEvents(result1, 'Deposit')
		expect(depositEvents.length).toBe(2)
		const [nftToAlice, nftToBob] = depositEvents
		const depositEvents2 = getEvents(result2, 'Deposit')
		expect(depositEvents2.length).toBe(1)
		const [nftToDavid] = depositEvents2
		expect(aliceIds.includes(nftToAlice.data.id)).toBe(true)
		expect(nft1.data.seriesNumber).toBe(1)
		expect(nft1.data.circulatingCount).toBe(3)
		expect(nft1.data.activityID).toBe(0)
		expect(nft1.data.isPositive).toBe(true)
		expect(nft1.data.bonus).toBe(toUFix64(1))

		expect(nft2.data.reciever).toBe(Bob)
		const [bobIds] = await shallResolve(getCollectionIds(Bob))
		expect(bobIds.includes(nft2.data.memorialId)).toBe(true)
		expect(nft2.data.memorialId).toBe(2)
		expect(bobIds.includes(nftToBob.data.id)).toBe(true)
		expect(nft2.data.seriesNumber).toBe(2)
		expect(nft2.data.circulatingCount).toBe(3)
		expect(nft2.data.activityID).toBe(0)
		expect(nft2.data.isPositive).toBe(true)
		expect(nft2.data.bonus).toBe(toUFix64(1))

		expect(nft3.data.reciever).toBe(David)
		const [DavidIds] = await shallResolve(getCollectionIds(David))
		expect(DavidIds.includes(nft3.data.memorialId)).toBe(true)
		expect(nft3.data.memorialId).toBe(3)
		expect(DavidIds.includes(nftToDavid.data.id)).toBe(true)
		expect(nft3.data.seriesNumber).toBe(3)
		expect(nft3.data.circulatingCount).toBe(3)
		expect(nft3.data.activityID).toBe(0)
		expect(nft3.data.isPositive).toBe(true)
		expect(nft3.data.bonus).toBe(toUFix64(1))

		const [result3] = await shallResolve(getActivity(0))
		expect(result3.closed).toBe(true)


		// user vote positive should has memorials
		const [AliceCollectionLength] = await shallResolve(getCollectionLength(Alice))
		expect(AliceCollectionLength).not.toBe(0)
		const [bobCollectionLength] = await shallResolve(getCollectionLength(Bob))
		expect(bobCollectionLength).not.toBe(0)
		const [chaierCollectionLength] = await shallResolve(getCollectionLength(Chaier))
		expect(chaierCollectionLength).toBe(0)
		const [davidCollectionLength] = await shallResolve(getCollectionLength(David))
		expect(davidCollectionLength).not.toBe(0)
		const [memorialsSupply] = await shallResolve(getMemorialsSupply())
		expect(memorialsSupply).toBe(3)

		// can get memorials information
		const [AliceCollectionIDs] = await shallResolve(getCollectionIds(Alice))
		const AlicememorialID = AliceCollectionIDs.pop()
		const [Alicememorial] = await shallResolve(getMemorial(Alice, AlicememorialID))
		expect(Alicememorial.activityID).toBe(0)
		expect(Alicememorial.isPositive).toBe(true)
		expect(Alicememorial.owner).toBe(Alice)
		const [BobCollectionIDs] = await shallResolve(getCollectionIds(Bob))
		const BobmemorialID = BobCollectionIDs.pop()
		const [Bobmemorial] = await shallResolve(getMemorial(Bob, BobmemorialID))
		expect(Bobmemorial.activityID).toBe(0)
		expect(Bobmemorial.isPositive).toBe(true)
		expect(Bobmemorial.owner).toBe(Bob)
		const [DavidCollectionIDs] = await shallResolve(getCollectionIds(David))
		const DavidmemorialID = DavidCollectionIDs.pop()
		const [Davidmemorial] = await shallResolve(getMemorial(David, DavidmemorialID))
		expect(Davidmemorial.activityID).toBe(0)
		expect(Davidmemorial.isPositive).toBe(true)
		expect(Davidmemorial.owner).toBe(David)
	})

	it("admin can set reward params, user can't", async () => {
		await deployActivity();
		const Admin = await getAdminAddress();
		const Alice = await getAccountAddress("Alice");
		const [rewardParams] = await shallResolve(getRewardParams())
		expect(rewardParams.maxRatio).toBe(toUFix64(5))
		expect(rewardParams.minRatio).toBe(toUFix64(1))
		expect(rewardParams.averageRatio).toBe(toUFix64(1.5))
		expect(rewardParams.asymmetry).toBe(toUFix64(2))

		const [result] = await shallResolve(updateRewardParams(Admin, {
			maxRatio: toUFix64(6),
			minRatio: toUFix64(1.1),
			averageRatio: toUFix64(1.3),
			asymmetry: toUFix64(2.0)
		}))
		const event = getEvent(result, 'rewardParameterUpdated')
		const newParams = event.data.newParams
		expect(newParams.maxRatio).toBe(toUFix64(6))
		expect(newParams.minRatio).toBe(toUFix64(1.1))
		expect(newParams.averageRatio).toBe(toUFix64(1.3))
		expect(newParams.asymmetry).toBe(toUFix64(2.0))

		const [rewardParams2] = await shallResolve(getRewardParams())
		expect(rewardParams2.maxRatio).toBe(toUFix64(6))
		expect(rewardParams2.minRatio).toBe(toUFix64(1.1))
		expect(rewardParams2.averageRatio).toBe(toUFix64(1.3))
		expect(rewardParams2.asymmetry).toBe(toUFix64(2))

		await shallRevert(updateRewardParams(Alice, {
			maxRatio: toUFix64(10),
			minRatio: toUFix64(1.2),
			averageRatio: toUFix64(1.3),
			asymmetry: toUFix64(2.0)
		}))

		// new.minRatio >= 1.0: "minRatio should gte 1.0"
		await shallRevert(updateRewardParams(Admin, {
			maxRatio: toUFix64(6),
			minRatio: toUFix64(0.9),
			averageRatio: toUFix64(1.3),
			asymmetry: toUFix64(2.0)
		}))

		// new.maxRatio > new.minRatio: "maxRatio should greater than minRatio"
		await shallRevert(updateRewardParams(Admin, {
			maxRatio: toUFix64(1.09),
			minRatio: toUFix64(1.1),
			averageRatio: toUFix64(1.3),
			asymmetry: toUFix64(2.0)
		}))

		// new.averageRatio > new.minRatio: "averageRatio should gt minRatio"
		await shallRevert(updateRewardParams(Admin, {
			maxRatio: toUFix64(6),
			minRatio: toUFix64(1.1),
			averageRatio: toUFix64(1.09),
			asymmetry: toUFix64(2.0)
		}))

		// new.averageRatio < new.maxRatio: "averageRatio should lt maxRatio"
		await shallRevert(updateRewardParams(Admin, {
			maxRatio: toUFix64(6),
			minRatio: toUFix64(1.1),
			averageRatio: toUFix64(6.5),
			asymmetry: toUFix64(2.0)
		}))

		// new.asymmetry > 0.0: "asymmetry should greater than 0"
		await shallRevert(updateRewardParams(Admin, {
			maxRatio: toUFix64(6),
			minRatio: toUFix64(1.1),
			averageRatio: toUFix64(1.3),
			asymmetry: toUFix64(0.0)
		}))

	})


	it("admin can change activity create comsuption, user can't", async () => {
		await deployActivity();
		const Admin = await getAdminAddress();
		const Alice = await getAccountAddress("Alice");
		await shallRevert(updateCreateConsumption(Alice, toUFix64(2.0)))

		const [result] = await shallResolve(updateCreateConsumption(Admin, toUFix64(3.0)))
		const consumptionUpdatedEvent = getEvent(result, 'consumptionUpdated')
		expect(consumptionUpdatedEvent).not.toBe(null)
		const eventData = consumptionUpdatedEvent.data
		expect(eventData.newPrice).toBe(toUFix64(3.0))
	})

	it("moderator can close spam activity", async () => {
		await deployActivity();
		const Admin = await getAdminAddress();
		const Alice = await getAccountAddress("Alice");
		const Bob = await getAccountAddress("Bob");
		await setupCCSTokenOnAccount(Bob)

		await shallResolve(createNewModerator(Alice, Admin))

		// Bob create activity
		const sendToBobAmount = 100
		const args =
			[
				[
					{ key: Bob, value: toUFix64(sendToBobAmount) }
				],
				t.Dictionary({ key: t.Address, value: t.UFix64 }),
			]

		await mintTokenAndDistribute(args)
		await createActivity(Bob, 'spam activity')

		// Alice can close spam activity
		await closeActivity(Alice, 0)
		const [result] = await shallResolve(getActivity(0))
		expect(result.closed).toBe(true)
	})

	it("can't batch mint nft if no activity when airdrop", async () => {
		await deployActivity();
		const Admin = await getAdminAddress();
		await setupCCSTokenOnAccount(Admin)
		const args =
			[
				[
					{ key: Admin, value: toUFix64(100) }
				],
				t.Dictionary({ key: t.Address, value: t.UFix64 }),
			]
		await mintTokenAndDistribute(args)

		const Alice = await getAccountAddress("Alice");
		await setupMemorialsOnAccount(Alice)


		// no activity
		await shallRevert(batchMintMemorials(Admin, 0, true, { [Alice]: true }, 0, true, 1))

		// activity has close
		await createAirdropActivity(Admin, 'test activity 0', [Alice])
		await shallResolve(batchMintMemorials(Admin, 0, true, { [Alice]: true }, 0, true, 1))
	})
})
