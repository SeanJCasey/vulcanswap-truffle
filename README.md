# Vulcan Swap: A Decentralized "Dollar-Cost Average" dApp Built on Ethereum

This project uses the Ethereum blockchain to generate and execute dollar-cost average orders in a decentralized pipeline.

## Repos

Vulcan Swap is divided across three Github repos for its client, 'backend', and the remote server used to simulate a cron job:

### vulcanswap-truffle (this repo)

This repo contains the Ethereum smart contracts that are deployed on the Rinkeby network as well as the contracts and migrations needed to launch a local Uniswap exchange framework for development. It is configured for development and deployment using the Truffle Framework.

### vulcanswap-client

https://github.com/SeanJCasey/vulcanswap-client

This repo contains the single page Drizzle / React frontend.

### vulcanswap-remote

https://github.com/SeanJCasey/vulcanswap-remote

This repo contains the Node script for executing the method on our smart contract that executes swaps on Uniswap for orders that are due for their next swap.

## Recommended Installation for the entire dApp:

1. Install Truffle globally: `npm install -g truffle`

2. Clone this repo and install dependencies
- `git clone git@github.com:SeanJCasey/vulcanswap-truffle.git vulcanswap`
- `npm i`

3. Clone the client repo into a `client` subdirectory and install dependencies
- `git clone git@github.com:SeanJCasey/vulcanswap-client.git client`
- `cd client`
- `npm i`
- `cd ..`
(Note: the `client/builds` folder is where truffle-config is set up to build its smart contracts for easy integration with frontend development).

4. Clone the remote repo into a `remote` subdirectory and install dependencies
- `git clone git@github.com:SeanJCasey/vulcanswap-remote.git remote`
- `cd remote`
- `npm i`
- `cd ..`

5. Deploy a local blockchain via Truffle Develop

(More instructions coming soon)
