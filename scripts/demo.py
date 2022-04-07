from utils import Web3Manager
import streamlit as st
import pandas as pd

import json
import yaml
import time

st.set_page_config(page_title='Tatopia',  layout='wide', page_icon=':shark:')
info = yaml.load(open('info.yaml'), Loader=yaml.FullLoader)

TaToPia = json.load(open("../artifacts/contracts/TaToPia.sol/TaToPia.json"))
TaToPiaFactory = json.load(open("../artifacts/contracts/TaToPiaFactory.sol/TaToPiaFactory.json"))
Potato = json.load(open("../artifacts/contracts/Potato.sol/Potato.json"))

w3 = Web3Manager("http://127.0.0.1:8545")
potato = w3.get_contract(address=info['potato_address'], abi=Potato['abi'])
factory = w3.get_contract(address=info['factory_address'], abi=TaToPiaFactory['abi'])

phases = {
    0: 'Seeding',
    1: 'Calculate',
    2: 'Budding',
    3: 'Flowering',
    4: 'Harvest',
    5: 'Sales'
}

def create_village(new_village_name, address_index):
    w3.transact(factory.functions.createVillage(new_village_name), address_index)

def create_land(new_village_number, new_village_name, address_index):
    w3.transact(factory.functions.createLand(new_village_number, new_village_name, w3.get_block_timestamp()), address_index)

def invest(upline, new_village_number, new_land_number, amount, address_index):
    w3.transact(factory.functions.invest(upline, new_village_number, new_land_number, amount), address_index)

def token_allowance(amount, address_index):
    w3.transact(potato.functions.approve(factory.address, amount), address_index)

def fast_forward(min, hour, day, week):
    w3.increase_time(min=min, hour=hour, day=day, week=week)
    w3.transact(potato.functions.approve(factory.address, 1), 0)

def reinvest(village_number, land_number, address_index):
    w3.transact(factory.functions.reinvest(village_number, land_number), address_index)

def opt_out(village_number, land_number, address_index):
    w3.transact(factory.functions.optOut(village_number, land_number), address_index)

def opt_out_withdraw(village_number, land_number, address_index):
    w3.transact(factory.functions.optOutWithdraw(village_number, land_number), address_index)

def proceed_phase(village_number, land_number, address_index):
    w3.transact(factory.functions.proceedToNextPhase(village_number, land_number), address_index)

def refund_seed_fail(village_number, address_index):
    w3.transact(factory.functions.refundSeedFail(village_number), address_index)

def migrate_seed_fail(village_number, address_index):
    w3.transact(factory.functions.migrateSeedFail(village_number), address_index)


villages = factory.functions.getVillages().call()

st.subheader('Blockchain Time')
latest_block_time = w3.get_block_timestamp()
local_time = time.strftime('%Y-%m-%d %H%M', time.localtime(latest_block_time))
st.text(f'Latest Block Timestamp: {latest_block_time}')
st.text(f'Local time: {local_time}')

with st.container():
    st.subheader('Address Stats')
    _address = st.selectbox('Choose address', [f'{idx} - {i}' for idx, i in enumerate(w3.accounts)])
    address_index, address = _address.split(' - ')
    address_index = int(address_index)
    balance = w3.get_eth_balance(address)


    df = pd.DataFrame(index=['-'])
    df['ETH balance'] = [balance]
    df['PTT balance'] = [potato.functions.balanceOf(address).call() * (10 ** -potato.functions.decimals().call())]
    df['PTT Allowance'] = [potato.functions.allowance(address, info['factory_address']).call() * (10 ** -potato.functions.decimals().call())]
    df['Upline'] = [factory.functions.getUpline(address).call()]
    df['Withdrawable'] = [factory.functions.getWithdrawableBonus(address).call()  * (10 ** -potato.functions.decimals().call())]

    st.dataframe(df)

# tatopia stats
with st.container():
    st.subheader('TaToPia Stats')
    df = pd.DataFrame(columns=['Village Number', 'Name', 'PTT Balance', 'Total Lands', 'Seeding Status'])
    for village in villages:
        village_contract = w3.get_contract(address=village, abi=TaToPia['abi'])
        number = village_contract.functions._villageNumber().call()
        name = village_contract.functions._villageName().call()
        n_lands = village_contract.functions.landCounter().call()
        seeding_status = village_contract.functions.getSeedingStatus().call()

        series = pd.DataFrame({
            'Village Number': int(number),
            'Name': name,
            'PTT Balance': village_contract.functions.getContractPTTBalance().call() * (10 ** -potato.functions.decimals().call()),
            'Total Lands': n_lands,
            'Seeding Status': 'end' if seeding_status[1] else 'ongoing'
        }, index=['-'])

        df = pd.concat([df, series], ignore_index=True)
    st.dataframe(df)

    # village stat
    if len(villages) > 0:
        _village = st.selectbox('Choose village', [f'{idx} - {i}' for idx, i in enumerate(villages)])
        village_index, village = _village.split(' - ')
        village_index = int(village_index)
        village_contract = w3.get_contract(address=village, abi=TaToPia['abi'])
        n_lands = village_contract.functions.landCounter().call()
        df = pd.DataFrame(columns=['Land Name', 'Land Number', 'Seed Start Local', 'Seed End Local', 'Funded', 'Target', 'Min Invest', 'Max Invest', 'Phase'])
        for n in range(n_lands):
            land_name, land_number, seed_start, seed_end, phase_start, phase_end, target, funded, reinvested, migrated, hit, phase = village_contract.functions.lands(n).call()
            series = pd.DataFrame({
                'Land Name': land_name,
                'Land Number': land_number,
                'Seed Start Local': time.strftime('%Y-%m-%d %H%M', time.localtime(seed_start)),
                'Seed End Local': time.strftime('%Y-%m-%d %H%M', time.localtime(seed_end)),
                'Phase End Local': (time.strftime('%Y-%m-%d %H%M', time.localtime(phase_end))) if phase_end < 12679314283 else 'Completed',
                'Target': target * (10 ** -potato.functions.decimals().call()),
                'Funded': funded * (10 ** -potato.functions.decimals().call()),
                'Min Invest': ((target * 0.001) if ((target * 0.001) > 1000) else target * 0.001) * (10 ** -potato.functions.decimals().call()),
                'Max Invest': target * 0.05 * (10 ** -potato.functions.decimals().call()),
                'Phase': phases[phase]
            }, index=['-'])
            df = pd.concat([df, series], ignore_index=True)
        st.dataframe(df)

        investments = factory.functions.getPlayerInvestments(address).call()
        df = pd.DataFrame(columns=['Land', 'Investment'])
        for idx, i in enumerate(investments[village_index]):
            series = pd.DataFrame({
                'Land': idx,
                'Investment': i * (10 ** -potato.functions.decimals().call())
            }, index=['-'])
            df = pd.concat([df, series], ignore_index=True)
        st.dataframe(df)

with st.container():
    st.subheader('Execute Functions')

    cols = st.columns(3)

    with cols[0]:
        st.info('Invest')
        upline = st.text_input('Upline', '0x0000000000000000000000000000000000000000')
        new_village_number = st.number_input('Village Number', value=0, key='invest')
        new_land_number = st.number_input('Land Number', value=0, key='invest')
        amount = st.number_input('Amount', value=0) * (10 ** potato.functions.decimals().call())
        st.button('Invest', on_click=invest, args=(upline, new_village_number, new_land_number, amount, address_index))

    with cols[1]:
        st.info('Create Village')
        new_village_name = st.text_input('New Village Name', '')
        st.button('Create Village', on_click=create_village, args=(new_village_name, address_index))

    with cols[2]:
        st.info('Create Land')
        new_village_number = st.number_input('New Village Number', value=0)
        new_land_name = st.text_input('New Land Name', '')
        st.button('Create Land', on_click=create_land, args=(new_village_number, new_land_name, address_index))

    cols = st.columns(3)
    with cols[0]:
        st.info('Proceed Next Phase')
        village_number = st.number_input('Village Number', value=0, key='proceed')
        land_number = st.number_input('Land Number', value=0, key='proceed')
        st.button('Proceed Phase', on_click=proceed_phase, args=(village_number, land_number, address_index))

    with cols[1]:
        st.info('Refund Seed Fail')
        village_number = st.number_input('Village Number', value=0, key='refund_seed_fail')
        st.button('Refund Seed Fail', on_click=refund_seed_fail, args=(village_number, address_index))

    with cols[2]:
        st.info('Migrate Seed Fail')
        village_number = st.number_input('Village Number', value=0, key='migrate_seed_fail')
        st.button('Migrate Seed Fail', on_click=migrate_seed_fail, args=(village_number, address_index))


    cols = st.columns(4)
    with cols[0]:
        st.info('Fast Forward Time')
        week = st.number_input('Week', value=0)
        day = st.number_input('Day', value=0)
        hour = st.number_input('Hour', value=0)
        min = st.number_input('Minute', value=0)
        st.button('Fast Forward', on_click=fast_forward, args=[min, hour, day, week])

    with cols[1]:
        st.info('Reinvest')
        village_number = st.number_input('Village Number', value=0, key='reinvest')
        land_number = st.number_input('Land Number', value=0, key='reinvest')
        st.button('Reinvest', on_click=reinvest, args=(village_number, land_number, address_index))

    with cols[2]:
        st.info('Opt Out')
        village_number = st.number_input('Village Number', value=0, key='opt_out')
        land_number = st.number_input('Land Number', value=0, key='opt_out')
        st.button('Opt Out', on_click=opt_out, args=(village_number, land_number, address_index))

    with cols[3]:
        st.info('Opt Out Withdraw')
        village_number = st.number_input('Village Number', value=0, key='opt_out_withdraw')
        land_number = st.number_input('Land Number', value=0, key='opt_out_withdraw')
        st.button('Opt Out Withdraw', on_click=opt_out_withdraw, args=(village_number, land_number, address_index))
