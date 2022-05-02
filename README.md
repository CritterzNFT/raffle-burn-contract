# Raffle Burn Contract

Raffle Burn allows you to raffle off NFTs for any ERC20 token. ERC20 tokens received from raffles are sent to the [0x000000000000000000000000000000000000dEaD](https://etherscan.io/address/0x000000000000000000000000000000000000dead) address. Anyone can add additional prizes to the raffle at any time.

# Test Locally

this project uses [foundry](https://github.com/foundry-rs/foundry)

1. `forge intall`
1. `forge test`

# Random Seed

Chainlink VRF v2 is used to generate the random seed for each raffle. After a raffle ends, anyone with a valid [Chainlink subscription account](https://vrf.chain.link/mainnet) can initialize the seed.
