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

        await tatopiaFactory.createVillage();
        const villages = await tatopiaFactory.getVillages();
        expect(villages.length).to.equal(1);

        const village = new ethers.Contract(villages[0], Tatopia.abi, waffle.provider);
        expect(await village.VILLAGE_NUMBER()).to.equal(0);
    })

    it("Create land", async () => {
        const { tatopiaFactory, potato, signers } = await waffle.loadFixture(fixture);

        await tatopiaFactory.createVillage();

        let now = Math.floor(Date.now() / 1000);

        await tatopiaFactory.createLand(0, now);
        let tatopia = await getVillage(tatopiaFactory, 0);
        let land0 = await tatopia.lands(0);

        expect(land0.phase).to.equal(0);
        expect(land0.seedStart).to.equal(now);
        expect(land0.phaseEndTime).to.equal(now + 2 * week - hour);
        expect(land0.target).to.equal(parseEther("10000"));
        expect(await tatopia.landLength()).to.equal(1);

        // create new land and check target
        let time = now + week
        await tatopiaFactory.createLand(0, time);
        let land1 = await tatopia.lands(1);

        const expected = parseEther("13000");
        expect(land1.target).to.equal(expected);
    })

    // it("Seeding", async () => {
    //     const { tatopia, potato, signers } = await waffle.loadFixture(fixture);
    //     let time = Math.floor(Date.now() / 1000) + hour;
    //     await tatopia.createLand(time);

    //     // canot invest before the start time (land will be created before the start time)
    //     await expect(tatopia.connect(signers[1]).invest(0, addressZero, parseEther("5"))).to.be
    //         .revertedWith("Land is not started yet");

    //     await network.provider.send("evm_increaseTime", [hour]);

    //     // send PTT to other user
    //     await potato.transfer(signers[1].address, parseEther("5000"));
         
    //     // cannot invest if not approved
    //     await expect(tatopia.connect(signers[1]).invest(0, addressZero, parseEther("200"))).to.be
    //         .revertedWith("Not enough token allowance");
        
    //     await potato.connect(signers[1]).approve(tatopia.address, parseEther("5000"));
    //     // cannot invest less than 1%
    //     await expect(tatopia.connect(signers[1]).invest(0, addressZero, parseEther("5"))).to.be
    //         .revertedWith("Seeding amount is less than minimum");
    //     // cannot invest more than 5%
    //     await expect(tatopia.connect(signers[1]).invest(0, addressZero, parseEther("501"))).to.be
    //         .revertedWith("Seeding amount exceeds maximum");
    // })

});
