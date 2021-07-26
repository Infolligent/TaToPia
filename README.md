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

# Running automated unit testing
1. Place JavaScript unit testing scripts in the ```test/``` folder.
1. Any file with ```.js``` or ```.ts``` extensions will be executed when running the automated smart contract testing.