from tqdm import tqdm
from utils import *
import json
import time

TaToPia = json.load(open("../artifacts/contracts/TaToPia.sol/TaToPia.json"))
TaToPiaFactory = json.load(open("../artifacts/contracts/TaToPiaFactory.sol/TaToPiaFactory.json"))
Potato = json.load(open("../artifacts/contracts/Potato.sol/Potato.json"))

w3 = Web3Manager("http://127.0.0.1:8545")
to_wei = w3.to_wei
potato = w3.deploy_contract(Potato)
tatopia_factory = w3.deploy_contract(TaToPiaFactory, [potato.address])

# send potato to users
for i in range(1, 50):
    w3.transact(potato.functions.transfer(w3.accounts[i], to_wei(5000)), 0)

# create village
w3.transact(tatopia_factory.functions.createVillage("Alpha"), 0)
print("[*] Alpha village created.")

# create land 1
w3.transact(tatopia_factory.functions.createLand(0, "Alpha 1", w3.get_block_timestamp()), 0)
print("[*] Alpha 1 land created.")

# seed!
for i in range(1, 21):
    w3.transact(potato.functions.approve(tatopia_factory.address, to_wei(500)), i)
    w3.transact(tatopia_factory.functions.invest(w3.accounts[0], 0, 0, to_wei(500)), i)
print("[*] Alpha 1 land seeding completed.")

w3.increase_time(week=2)
w3.transact(tatopia_factory.functions.proceedToNextPhase(0, 0))

# create land 2
w3.transact(tatopia_factory.functions.createLand(0, "Alpha 2", w3.get_block_timestamp()), 0)
print("[*] Alpha 2 land created.")
