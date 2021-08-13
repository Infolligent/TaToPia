from web3 import Web3

class Web3Manager:
    def __init__(self, rpc_url, gas_limit=10e+6):
        self.provider = Web3.HTTPProvider(rpc_url)
        self.w3 = Web3(self.provider)
        assert self.w3.isConnected()

        self.accounts = self.w3.eth.accounts
        self.gas_limit = int(gas_limit)

    def transact(self, pre_txn, account=0, value=0):
        txn_hash = pre_txn.transact({"from": self.accounts[account], "gas": self.gas_limit, "nonce": self.w3.eth.getTransactionCount(self.accounts[account]), "value": value})

        transaction_receipt = self.w3.eth.waitForTransactionReceipt(txn_hash)
        assert transaction_receipt["status"], "Transaction failed"
            
        return transaction_receipt

    def deploy_contract(self, contract_json, constructor_arguments=None):
        if constructor_arguments is None:
            receipt = self.transact(self.w3.eth.contract(
                    abi=contract_json['abi'],
                    bytecode=contract_json['bytecode']).constructor(), 0
                )
        else:
            receipt = self.transact(self.w3.eth.contract(
                    abi=contract_json['abi'],
                    bytecode=contract_json['bytecode']).constructor(*constructor_arguments), 0
                )
        
        contract_name = contract_json["contractName"]
        contract_address = receipt['contractAddress']
        contract = self.w3.eth.contract(abi=contract_json["abi"], address=contract_address)
        gas_used = self.get_gas_used(receipt)
        print("[*] {} contract deployed at {} ({} gas used).".format(contract_name, contract_address, gas_used))

        return contract

    def get_contract(self, abi, address):
        contract = self.w3.eth.contract(abi=abi, address=address)

        return contract

    def to_wei(self, value):
        return Web3.toWei(value, "ether")

    def get_gas_used(self, receipt):
        return receipt["gasUsed"]

    def get_block_timestamp(self):
        return self.w3.eth.get_block("latest")["timestamp"]

    def increase_time(self, value=0, hour=0, day=0, week=0):
        if value == 0:
            time_increment = hour * 3600 + day * 86400 + week * 604800
        else:
            time_increment = value

        self.provider.make_request("evm_increaseTime", [int(time_increment)])