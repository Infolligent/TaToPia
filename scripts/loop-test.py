from web3 import Web3
import json
import time
import threading
import numpy as np

localnet = "http://127.0.0.1:8545"
w3 = Web3(Web3.HTTPProvider(localnet))

assert w3.isConnected()

accounts = w3.eth.accounts

def transact(pre_txn, n, value=0, wait_for_receipt=True):
    txn_hash = pre_txn.transact({"from": accounts[n], "gas": 500000, "nonce": w3.eth.getTransactionCount(accounts[n]), "value": value})
    #print("Transaction Hash: {}\n".format(txn_hash.hex()))
    if wait_for_receipt:
        transaction_receipt = w3.eth.waitForTransactionReceipt(txn_hash)
        return transaction_receipt
    

def get_gas(receipt):
    return receipt["gasUsed"]

contract_json = json.load(open("../artifacts/contracts/LoopTest.sol/LoopTest.json"))

print("[*] Deploying contract...")
receipt = transact(w3.eth.contract(
                abi=contract_json['abi'],
                bytecode=contract_json['bytecode']).constructor(), 0
            )
contract_address = receipt['contractAddress']
# contract object
contract = w3.eth.contract(abi=contract_json["abi"], address=contract_address)
print("[*] Contract deployed at {}".format(contract_address))

print("[*] Simulating users entering...")
def thread_fn(_start, _stop, name):
    intervals = np.linspace(_start, _stop, 4, endpoint=False, dtype=int).tolist()
    for i in range(_start, _stop):
        transact(contract.functions.store(), i, wait_for_receipt=False)
        if i in intervals:
            percent = intervals.index(i) * 25
            print("[*] {} thread {}% done".format(name, percent))

    print("[*] {} thread complete!".format(name))

threads = []
nums = np.linspace(0, 500, 10, endpoint=False, dtype=int)
tick = time.time()
for idx, i in enumerate(nums):
    x = threading.Thread(target=thread_fn, args=(i, i+50, idx))
    threads.append(x)
    x.start()

for t in threads:
    t.join()

tock = time.time()

print("[*] Simulation took {} seconds".format(tock-tick))
counter = contract.functions.counter().call()
print("[*] Counter value: {}".format(counter))

print("[*] Running single call...")
receipt = transact(contract.functions.singleCall(0), 0)
print(receipt)

# print("[*] Running big loop for 0-20")
# receipt = transact(contract.functions.bigLoop(0, 20), 0)
# print(receipt)

# print(" ")
# print("[*] Running big loop for 1000-4999")
# receipt = transact(contract.functions.bigLoop(1000, 4999), 0)
# print(receipt)