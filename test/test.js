const { expect } = require("chai");
const { waffle, ethers, network } = require("hardhat");
const { time } = require("@openzeppelin/test-helpers");

const Potato = require("../artifacts/contracts/ERC20.sol/Potato.json");
const Tatopia = require("../artifacts/contracts/TaToPia.sol/TaToPia.json");

const BN = ethers.BigNumber;
const parseEther = ethers.utils.parseEther;  // convert ETH -> wei

const week = 604800;
const day = 86400;
const hour = 3600;

describe("TaToPia", function() {
    async function fixture() {
        const signers = await ethers.getSigners();
        const potato = await waffle.deployContract(signers[0], Potato);
        const tatopia = await waffle.deployContract(signers[0], Tatopia, [potato.address]);

        return { tatopia, potato, signers };
    }

    it("Create land", async () => {
        const { tatopia, potato, signers } = await waffle.loadFixture(fixture);
        
        const now = Math.floor(Date.now() / 1000);

        await tatopia.createLand(now);
        let land0 = await tatopia.lands(0);

        expect(land0.phase).to.equal(0);
        expect(land0.phaseStartTime).to.equal(now);
        expect(land0.phaseEndTime).to.equal(now + week - hour);
        expect(land0.target).to.equal(parseEther("10000"));
        expect(await tatopia.landLength()).to.equal(1);

        // await network.provider.send("evm_increaseTime", [604800+3600])
        // await tatopia.proceedToNextPhase(0);

        // land0 = await tatopia.lands(0);
        // expect(land0.phase).to.equal(1);
    })

});
