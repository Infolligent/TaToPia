const PTT = artifacts.require("PTT");

module.exports = async function (deployer, network, addresses) {
  // constructor arguments:
  // name, symbol, decimal, presales cap, individual cap, rate
  await deployer.deploy(
    PTT,
    "Potato Token",
    "PTT",
    "0x63EfAC344DFf2C72cE0d9b75ebC746Bfff3611F8",
    "20000000000000000000000000000" // 20 billion, 18 decimals
  );
};
