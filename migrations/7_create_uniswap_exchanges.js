const UniswapFactory = artifacts.require("./uniswap_factory");
const UniswapExchangeInterface = artifacts.require("./UniswapExchangeInterface");
const UniswapFactoryInterface = artifacts.require("./UniswapFactoryInterface");
const SeanToken = artifacts.require("./SeanToken");
const MoonToken = artifacts.require("./MoonToken");
const ConsensysToken = artifacts.require("./ConsensysToken");
const FakeDai = artifacts.require("./FakeDai");

module.exports = (deployer, network, accounts) => {
    // Create fake exchanges if not a Uniswap-supported network
    if (!["mainnet, rinkeby"].includes(network)) {
        let iFactory;
        deployer
            // 1. Instantiate a uniswap factory interface with the deployed factory.
            .then(() => UniswapFactory.deployed())
            .then(instance => UniswapFactoryInterface.at(instance.address))
            .then(instance => iFactory = instance)

            // 2. Create a uniswap exchange for each token.
            .then(() => FakeDai.deployed())
            .then(instance => createExchangeWithLiquidity(
                iFactory, instance, web3.utils.toWei("5", "ether"), web3.utils.toWei("1000")))
            .then(() => SeanToken.deployed())
            .then(instance => createExchangeWithLiquidity(
                iFactory, instance, web3.utils.toWei("3"), web3.utils.toWei("10000")))
            .then(() => MoonToken.deployed())
            .then(instance => createExchangeWithLiquidity(
                iFactory, instance, web3.utils.toWei("2"), web3.utils.toWei("5000")))
            .then(() => ConsensysToken.deployed())
            .then(instance => createExchangeWithLiquidity(
                iFactory, instance, web3.utils.toWei("0.3"), web3.utils.toWei("2000")))
            .catch(err => console.log(err));
    }
    else {
        console.log("Skipped migration: create uniswap exchanges")
    }
};

const createExchangeWithLiquidity = (iFactory, token, amountEth, amountTokens) => {
    let exchangeAddress;

    return iFactory.createExchange(token.address)
        .then(() => iFactory.getExchange(token.address))
        .then(result => exchangeAddress = result)
        .then(() => token.approve(exchangeAddress, amountTokens, {gas: 6500000, gasPrice: 2000000000}))
        .then(() => UniswapExchangeInterface.at(exchangeAddress))
        .then(exchange => {
            const min_liquidity = 0;
            const max_tokens = amountTokens;
            const deadline = Math.floor(Date.now() / 1000) + 300;
            exchange.addLiquidity(min_liquidity, max_tokens, deadline, {value: amountEth, gas: 6500000, gasPrice: 2000000000});
        })
        .then(async () => console.log(`Exchange for ${await token.symbol()} at ${exchangeAddress}`));
}
