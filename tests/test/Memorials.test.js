import path from "path";
import { emulator, init, shallPass, shallResolve } from "flow-js-testing";
import { deployMemorials, setupMemorialsOnAccount, getMemorialsSupply } from "../src/Memorials";
import { getAdminAddress } from "../src/common";

// We need to set timeout for a higher number, because some transactions might take up some time
jest.setTimeout(500000);

describe("Memorials", () => {
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

	it("shall deploy Memorials contract correctly", async () => {
		// Deploy contract
		await shallPass(deployMemorials());
	});

	it("supply shall be 0 after contract is deployed", async () => {
		// Setup
		await deployMemorials();
		const Admin = await getAdminAddress();
		await shallPass(setupMemorialsOnAccount(Admin));

		const [supply] = await shallResolve(getMemorialsSupply())
		expect(supply).toBe(0);
	});
});