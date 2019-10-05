# Vulcan Swap: A Decentralized Cost Averaging dApp Built on Ethereum

This project uses the Ethereum blockchain to generate and execute "cost average" orders in a decentralized pipeline. For example:

"Use 100 DAI to buy ETH in 5 batches of 20 DAI, one per day."

## Repos

Vulcan Swap is divided across three Github repos:

- a smart contracts backend (this repo)
- a React and Drizzle-based client (`vulcanswap-client`)
- a serverless script used to queue order execution (`vulcanswap-remote`)

### `vulcanswap-truffle` (this repo)

This repo contains the Ethereum smart contracts that are deployed on the Rinkeby network, as well as the contracts and Truffle migrations needed to set up a local development environment with Compound loans and Uniswap's exchange framework. It is configured for development and deployment using the Truffle Framework.

(Note: the migrations only initialize a Compound instance enough to be able to mint and redeem cTokens. It does not provide a Price Oracle or allow for collateralizing or taking out loans.)

### `vulcanswap-client`

https://github.com/SeanJCasey/vulcanswap-client

This repo contains the single page dApp, built on a React + Drizzle frontend.

### `vulcanswap-remote`

https://github.com/SeanJCasey/vulcanswap-remote

This repo contains the Node script for calling and executing the `checkConversionDueAll()` and `executeDueConversion()` methods on the `CostAverageOrderBook` smart contract. This is how Uniswap swaps are triggered for orders after a particular amount of time has elapsed.


## Recommended Installation for the entire dApp:

1. Install Truffle globally: `npm install -g truffle`

2. Clone this repo and install dependencies
`git clone git@github.com:SeanJCasey/vulcanswap-truffle.git vulcanswap && cd vulcanswap && npm i`

3. Clone the client repo into a `client` subdirectory and install dependencies
`git clone git@github.com:SeanJCasey/vulcanswap-client.git client && cd client && npm i && cd..`

(Note: the `client/builds` folder is where `truffle-config.js` is set up to build its smart contracts for easy integration with frontend development.)

4. Clone the serverless script into a `remote` subdirectory and install dependencies
`git clone git@github.com:SeanJCasey/vulcanswap-remote.git remote && cd remote && npm i & cd..`

5. Deploy a local blockchain with Vulcan Swap's main smart contract, plus mock ERC20 tokens, Uniswap, and Compound
`truffle develop`

Then at the `develop>` prompt:

`compile`
`migrate`

6. In a new tab, spin up the client.

`cd client && npm start`

Voila! You should be ready to "Go long and prosper" locally.
