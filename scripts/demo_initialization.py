from utils import Web3Manager
import json
import yaml

w3 = Web3Manager("http://127.0.0.1:8545")
TaToPia = json.load(open("../artifacts/contracts/TaToPia.sol/TaToPia.json"))
TaToPiaFactory = json.load(open("../artifacts/contracts/TaToPiaFactory.sol/TaToPiaFactory.json"))
Potato = json.load(open("../artifacts/contracts/Potato.sol/Potato.json"))

potato = w3.deploy_contract(Potato)
tatopia_factory = w3.deploy_contract(TaToPiaFactory, [potato.address])

# send potato to users
for i in range(1, 50):
    w3.transact(potato.functions.transfer(w3.accounts[i], w3.to_wei(5000)), 0)

info = {
    'potato_address': potato.address,
    'factory_address': tatopia_factory.address
}

with open('info.yaml', 'w') as file:
    yaml.dump(info, file)