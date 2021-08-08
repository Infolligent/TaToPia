const { expect } = require("chai");
const { waffle, ethers, network } = require("hardhat");

const Potato = require("../artifacts/contracts/ERC20.sol/Potato.json");
const TaToPiaFactory = require("../artifacts/contracts/TaToPiaFactory.sol/TaToPiaFactory.json");
const Tatopia = require("../artifacts/contracts/TaToPia.sol/TaToPia.json");

const BN = ethers.BigNumber;
const parseEther = ethers.utils.parseEther;  // convert ETH -> wei

const week = 604800;
const day = 86400;
const hour = 3600;

const addressZero = ethers.constants.AddressZero;

describe("TaToPia", function() {
    async function fixture() {
        const signers = await ethers.getSigners();
        // contract deployer is minted with POTATO tokens
        const potato = await waffle.deployContract(signers[0], Potato);
        const tatopiaFactory = await waffle.deployContract(signers[0], TaToPiaFactory, [potato.address]);

        return { tatopiaFactory, potato, signers };
    }

    async function getVillage(factory, i) {
        const villages = await factory.getVillages();
        const tatopia = new ethers.Contract(villages[i], Tatopia.abi, waffle.provider);

        return tatopia
    }

    it("Create village", async () => {
        const { tatopiaFactory, potato, signers } = await waffle.loadFixture(fixture);

        await tatopiaFactory.createVillage("Alpha");
        const villages = await tatopiaFactory.getVillages();
        expect(villages.length).to.equal(1);

        const village = new ethers.Contract(villages[0], Tatopia.abi, waffle.provider);
        expect(await village.VILLAGE_NUMBER()).to.equal(0);
    })

    it("Create land", async () => {
        const { tatopiaFactory, potato, signers } = await waffle.loadFixture(fixture);

        await tatopiaFactory.createVillage("Alpha1");

        let now = Math.floor(Date.now() / 1000);

        await tatopiaFactory.createLand(0, "Alpha 1", now);
        let tatopia = await getVillage(tatopiaFactory, 0);
        let land0 = await tatopia.lands(0);

        expect(land0.phase).to.equal(0);
        expect(land0.seedStart).to.equal(now);
        expect(land0.phaseEndTime).to.equal(now + 2 * week - hour);
        expect(land0.target).to.equal(parseEther("10000"));
        expect(await tatopia.landCounter()).to.equal(1);
    })

    it("Seeding", async () => {
        const { tatopiaFactory, potato, signers } = await waffle.loadFixture(fixture);

        await tatopiaFactory.createVillage("Alpha");
        let now = Math.floor(Date.now() / 1000) + hour;
        await tatopiaFactory.createLand(0, "Alpha 1", now);

        // cannot invest if not approved
        await expect(tatopiaFactory.invest(0, 0, parseEther("200"))).to.be
            .revertedWith("Not enough token allowance");
        
        await potato.approve(tatopiaFactory.address, parseEther("5000"));

        // cannot invest before the start time (land will be created before the start time)
        await expect(tatopiaFactory.invest(0, 0, parseEther("5"))).to.be
            .revertedWith("Land is not started yet");

        // fast forward 1 hour
        await network.provider.send("evm_increaseTime", [hour]);
   
        // cannot invest less than 1% of total seeding amount 10000
        await expect(tatopiaFactory.invest(0, 0, parseEther("5"))).to.be
            .revertedWith("Seeding amount is less than minimum");
        // cannot invest more than 5%
        await expect(tatopiaFactory.invest(0, 0, parseEther("501"))).to.be
            .revertedWith("Seeding amount exceeds maximum");

        await tatopiaFactory.invest(0, 0, parseEther("100"));
        let invested = (await tatopiaFactory.getPlayerInvestments(signers[0].address))[0][0];
        expect(invested).to.be.equal(parseEther("100"));
    })

    it("Moving to Calculate phase and creating new lands", async() => {
        const { tatopiaFactory, potato, signers } = await waffle.loadFixture(fixture);

        await tatopiaFactory.createVillage("Alpha");
        let now = Math.floor(Date.now() / 1000);
        await tatopiaFactory.createLand(0, "Alpha 1", now);

        // send 500 tokens to 19 users first, 500 x 20 = 10000
        // user invests
        for (var i=1; i<20; i++) {
            await potato.transfer(signers[i].address, parseEther("500"));
            await potato.connect(signers[i]).approve(tatopiaFactory.address, parseEther("500"));
            await tatopiaFactory.connect(signers[i]).invest(0, 0, parseEther("500"));
        }

        // try create new land before finish seeding
        await expect(tatopiaFactory.createLand(0, "Alpha 2", now)).to.be
            .revertedWith("Previous land has not hit seeding target");
        
        // last user invest
        await potato.transfer(signers[21].address, parseEther("500"));
        await potato.connect(signers[21]).approve(tatopiaFactory.address, parseEther("500"));
        await tatopiaFactory.connect(signers[21]).invest(0, 0, parseEther("500"));

        // moving to calculate phase before seed phase end
        await expect(tatopiaFactory.proceedToNextPhase(0, 0)).to.be
            .revertedWith("Not the time yet");
        
        // create new land
        expect(await tatopiaFactory.createLand(0, "Alpha 2", now));
        const village = await getVillage(tatopiaFactory, 0);
        expect(await village.landCounter()).to.be.equal(2);
        expect((await village.lands(0)).hit).to.be.true;

        // fast forward time and proceed to next phase
        await network.provider.send("evm_increaseTime", [2*week - hour]);
        await tatopiaFactory.proceedToNextPhase(0, 0);
        expect((await village.lands(0)).phase).to.be.equal(1);
    })

});
