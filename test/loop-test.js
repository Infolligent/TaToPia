const { expect } = require("chai");
const { waffle, ethers, network } = require("hardhat");
const { isCallTrace } = require("hardhat/internal/hardhat-network/stack-traces/message-trace");

const LoopTest = require("../artifacts/contracts/LoopTest.sol/LoopTest.json");

const BN = ethers.BigNumber;
const parseEther = ethers.utils.parseEther;

describe("TaToPia", function() {
    async function fixture() {
        const signers = await ethers.getSigners();
        const loopTest = await waffle.deployContract(signers[0], LoopTest);

        // for (let i=0; i < 500; i++) {
        //     await loopTest.connect(signers[i]).store();
        // }

        return { loopTest, signers };
    }

    // it("Big Loop", async () => {
    //     const { loopTest, signers } = await waffle.loadFixture(fixture);
        
    //     console.log("haha");
    //     await loopTest.bigLoop(0, 500);
    //     const flag = await loopTest.flag();
    //     expect(flag);
    // })

    it("Gas test", async () => {
        const { loopTest, signers } = await waffle.loadFixture(fixture);
        let n = await loopTest.noGasLoop(20);
        expect(n).to.be.equal(5020);

        await loopTest.stateChange(50);
        let j = await loopTest.number();
        expect(j).to.be.equal(5050);
    })

});