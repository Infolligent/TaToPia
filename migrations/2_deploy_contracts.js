const PTT = artifacts.require("PTT");
const FlatPTT = artifacts.require("FlatPTT");

module.exports = async function (deployer, network, addresses) {
  // constructor arguments:
  // name, symbol, presales cap, individual cap, rate
  await deployer.deploy(
    PTT,
    "Potato",
    "PTT",
    "0x74Fd905b0b189F6AeFC0238eC3EAa9Ed83E194e8",
    "20000000000000000000000000000", // 20 billion, 18 decimals
    "0xc5B33B5643699B37d7174f4BA16Ce7b9d6cBb1cB",
    "0xB9c1Fcc221188d974EB6be8e31909cB0A56A1AF8",
  );

  const instance = await PTT.deployed();
  console.log(instance);
};
