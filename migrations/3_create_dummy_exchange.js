const UniswapFactory = artifacts.require("./uniswap_factory");
const UniswapExchangeInterface = artifacts.require("./UniswapExchangeInterface");
const UniswapFactoryInterface = artifacts.require("./UniswapFactoryInterface");
const SeanToken = artifacts.require("./SeanToken");
const MoonToken = artifacts.require("./MoonToken");
const ConsensysToken = artifacts.require("./ConsensysToken");

module.exports = (deployer, network, accounts) => {
    const uniswapFactoryAddresses = {
        mainnet: "0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95",
        rinkeby: "0xf5D915570BC477f9B8D6C0E980aA81757A3AaC36"
    }

    // Create fake tokens if not mainnet
    if (network !== 'mainnet') {
        let iFactory;

        deployer
            .then(() => {
                if (!(network in uniswapFactoryAddresses)) {
                    return UniswapFactory.deployed()
                        .then(instance => uniswapFactoryAddresses[network] = instance.address)
                }
            })
            .then(() => UniswapFactoryInterface.at(uniswapFactoryAddresses[network]))
            .then(instance => iFactory = instance)
            .then(() => SeanToken.deployed())
            .then(instance => createExchangeWithLiquidity(
                iFactory, instance, 5000000000000000000, 10000))
            .then(() => MoonToken.deployed())
            .then(instance => createExchangeWithLiquidity(
                iFactory, instance, 10000000000000000000, 300000))
            .then(() => ConsensysToken.deployed())
            .then(instance => createExchangeWithLiquidity(
                iFactory, instance, 3000000000000000000, 500000))
            .catch(err => console.log(err));
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
}
