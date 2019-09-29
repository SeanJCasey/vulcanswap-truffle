const CostAverageOrderBook = artifacts.require("./CostAverageOrderBook");

module.exports = (deployer, network) => {
    const uniswapFactoryAddresses = {
        mainnet: "0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95",
        rinkeby: "0xf5D915570BC477f9B8D6C0E980aA81757A3AaC36"
    };

    if (!(network in uniswapFactoryAddresses)) {
        // Add uniswap factory to addresses
        const UniswapFactory = artifacts.require("./uniswap_factory");
        uniswapFactoryAddresses[network] = UniswapFactory.address;
    }

    // Deploy the main contract
    deployer.deploy(CostAverageOrderBook, uniswapFactoryAddresses[network])
};
