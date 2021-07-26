# Setup
1. Clone this repo and cd into the repo folder.
1. Install dependencies, run the following command  
```$ npm install```

# Project Structure

```
.
├── artifacts
│   ├── build-info
│   ├── contracts
│   ├── hardhat
│   └── @openzeppelin
├── cache
│   └── solidity-files-cache.json
├── contracts
│   ├── ERC20.sol
│   ├── LoopTest.sol
│   ├── TaToPiaFactory.sol
│   └── TaToPia.sol
├── hardhat.config.js
├── package.json
├── package-lock.json
├── README.md
├── scripts
│   ├── loop-test.py
│   └── sample-script.js
└── test
    ├── loop-test.js.bck
    └── test.js

9 directories, 13 files
```

## Quick rundown on project structure
### artifacts
The ```artifacts``` folder contains compiled contract bytecodes and abi in JSON format. The compiled contracts are in the ```contracts``` folder here. For example, the JSON for the contract ```TaToPia.sol``` will be in ```artifacts/contracts/TaToPia.sol/TaToPia.json```.

### contracts
Stores the smart contracts of the project.

### scripts
Scripts that can be run for testing or deploying smart contracts.

### test
Unit testing scripts for the smart contracts. Any file with ```.js``` or ```.ts``` extensions will be executed when running the automated smart contract testing.

# Compiling the smart contracts
```
$ npx hardhat compile
Compiling 8 files with 0.8.4
Compilation finished successfully
```

# Project smart contract layout
```
                       ┌───────────────────┐
                       │                   │
                       │                   │
                       │                   │
                       │  TaToPia Factory  │
                       │                   │
                       │                   │
                       │___________________│
                                 |         
      ┌────────────────-┬─────────────────┬-──────────────────┐
      │                 │                 │                   │
      │                 │                 │                   │
      │                 │                 │                   │
      │                 │                 │                   │
      │                 │                 │                   │
      │                 │                 │                   │
      │                 │                 │                   │
┌─────▼─────┐     ┌─────▼─────┐     ┌─────▼─────┐      ┌──────▼────┐
│           │     │           │     │           │      │           │
│           │     │           │     │           │      │           │
│  TaToPia  │     │  TaToPia  │     │  TaToPia  │      │  TaToPia  │
│           │     │           │     │           │      │           │
│           │     │           │     │           │      │           │
│           │     │           │     │           │      │           │
└───────────┘     └───────────┘     └───────────┘      └───────────┘
```

1. Contracts are all in the ```contracts``` folder.
1. ```TaToPiaFactory.sol``` is the master contract.
1. ```TaToPia.sol``` is the village contract. The factory contract will deploy a new instance of ```TaToPia.sol``` to create a new village.
1. ```ERC20.sol``` is a mock ERC20 token to mock the functionality of the Potato (PTT) token. This is required for testing.

# Running automated unit testing
1. Place JavaScript unit testing scripts in the ```test/``` folder.
1. Any file with ```.js``` or ```.ts``` extensions will be executed when running the automated smart contract testing.
1. Run the test, execute:
```
$ npx hardhat test

  TaToPia
    ✓ Create village
    ✓ Create land
    ✓ Seeding
    ✓ Moving to Calculate phase and creating new lands

·------------------------------------|---------------------------|-------------|-----------------------------·
|        Solc version: 0.8.4         ·  Optimizer enabled: true  ·  Runs: 200  ·  Block limit: 12450000 gas  │
·····································|···························|·············|······························
|  Methods                                                                                                   │
···················|·················|·············|·············|·············|···············|··············
|  Contract        ·  Method         ·  Min        ·  Max        ·  Avg        ·  # calls      ·  usd (avg)  │
···················|·················|·············|·············|·············|···············|··············
|  Potato          ·  approve        ·      46263  ·      46275  ·      46264  ·           21  ·          -  │
···················|·················|·············|·············|·············|···············|··············
|  Potato          ·  transfer       ·      51585  ·      51597  ·      51596  ·           20  ·          -  │
···················|·················|·············|·············|·············|···············|··············
|  TaToPiaFactory  ·  createLand     ·     169624  ·     177548  ·     171605  ·            4  ·          -  │
···················|·················|·············|·············|·············|···············|··············
|  TaToPiaFactory  ·  createVillage  ·          -  ·          -  ·    1996433  ·            4  ·          -  │
···················|·················|·············|·············|·············|···············|··············
|  TaToPiaFactory  ·  invest         ·     137803  ·     189103  ·     141375  ·           20  ·          -  │
···················|·················|·············|·············|·············|···············|··············
|  Deployments                       ·                                         ·  % of limit   ·             │
·····································|·············|·············|·············|···············|··············
|  Potato                            ·          -  ·          -  ·     643132  ·        5.2 %  ·          -  │
·····································|·············|·············|·············|···············|··············
|  TaToPiaFactory                    ·          -  ·          -  ·    2847652  ·       22.9 %  ·          -  │
·------------------------------------|-------------|-------------|-------------|---------------|-------------·

  4 passing (3s)

```

