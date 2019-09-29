const CostAverageOrderBook = artifacts.require("./CostAverageOrderBook");

module.exports = (deployer, network) => {
    // If not mainnet or rinkeby, deploy uniswap mock contracts
    if (!["mainnet", "rinkeby"].includes(network)) {
        const UniswapExchange = artifacts.require("./uniswap_exchange");
        const UniswapFactory = artifacts.require("./uniswap_factory");

        // Deploy FakeDai
        deployer.deploy(UniswapExchange)
            // Deploy and initialize Uniswap Factory
            .then(() => deployer.deploy(UniswapFactory))
            .then(instance => instance.initializeFactory(UniswapExchange.address))
    }
    else {
        console.log("Skipped migration: deploy uniswap")
    }
};
