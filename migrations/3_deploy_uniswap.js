module.exports = (deployer, network) => {
    const liveNetworks = ["mainnet", "rinkeby"];
    const nonDevNetworks = [
        ...liveNetworks,
        ...liveNetworks.map(liveNetwork => `${liveNetwork}-fork`)
    ];
    if (!nonDevNetworks.includes(network)) {
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
