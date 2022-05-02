# Raffle Burn Contract

Raffle Burn allows you to raffle off NFTs for any ERC20 token. ERC20 tokens received from raffles are sent to the [0x000000000000000000000000000000000000dEaD](https://etherscan.io/address/0x000000000000000000000000000000000000dead) address. Anyone can add additional prizes to the raffle at any time.

# Test Locally

this project uses [foundry](https://github.com/foundry-rs/foundry)

1. `forge intall`
1. `forge test`

# Random Seed

Chainlink VRF v2 is used to generate the random seed for each raffle. After a raffle ends, anyone with a valid [Chainlink subscription account](https://vrf.chain.link/mainnet) can initialize the seed.

Rinkeby Key Hash (30 gwei): 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc

Mainnet Key Hash (200 gwei): 0x8af398995b04c28e9951adb9721ef74c74f93e6a478f39e7e0777be13527e7ef

# Deployment

## Rinkeby

Deploy

```sh
forge create --chain rinkeby \
    --rpc-url https://rinkeby.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161 \
    --constructor-args 0x6168499c0cFfCaCD319c818142124B7A15E857ab \
    --gas-price 50000000000 \
    -i src/RaffleBurn.sol:RaffleBurn
```

Verify

compiler-version can be found in `cache/solidity-files-cache.json` under `artifacts`

```sh
forge verify-contract --chain-id 4 \
    --num-of-optimizations 200 \
    --constructor-args \
    (cast abi-encode "constructor(address)" 0x6168499c0cFfCaCD319c818142124B7A15E857ab) \
    --compiler-version v0.8.13+commit.abaa5c0e \
    <the_contract_address> src/RaffleBurn.sol:RaffleBurn <your_etherscan_api_key>
```

Check Verify Status

```sh
forge verify-check --chain-id 4 <GUID> <your_etherscan_api_key>
```

## Mainnet

Deploy

```sh
forge create --rpc-url https://rpc.ankr.com/eth/ \
  --constructor-args 0x271682DEB8C4E0901D1a1550aD2e64D568E69909 \
  --gas-price 50000000000 \
  -i src/RaffleBurn.sol:RaffleBurn
```

Verify

compiler-version can be found in `cache/solidity-files-cache.json` under `artifacts`

```sh
forge verify-contract --chain-id 1 \
    --num-of-optimizations 200 \
    --constructor-args \
    (cast abi-encode "constructor(address)" 0x271682DEB8C4E0901D1a1550aD2e64D568E69909) \
    --compiler-version v0.8.13+commit.abaa5c0e \
    <the_contract_address> src/RaffleBurn.sol:RaffleBurn <your_etherscan_api_key>
```

Check Verify Status

```sh
forge verify-check --chain-id 1 <GUID> <your_etherscan_api_key>
```
