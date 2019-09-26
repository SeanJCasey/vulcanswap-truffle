const CostAverageOrderBook = artifacts.require("./CostAverageOrderBook");

module.exports = (deployer, network) => {
    const uniswapFactoryAddresses = {
        mainnet: "0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95",
        rinkeby: "0xf5D915570BC477f9B8D6C0E980aA81757A3AaC36"
    };
    const daiAddresses = {
        mainnet: "0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359",
        rinkeby: "0x2448eE2641d78CC42D7AD76498917359D961A783"
    };

    const initializeCostAverageOrderBook = (instance, daiAddress) => {
        const minDai = 200;
        const maxDai = 20000;
        instance.updateSourceCurrency(
            daiAddress,
            web3.utils.toWei(String(minDai), 'ether'),
            web3.utils.toWei(String(maxDai), 'ether')
        );
    }

    // If not mainnet or rinkeby, deploy uniswap mock contracts
    if (!(network in uniswapFactoryAddresses)) {
        const ConsensysToken = artifacts.require("./ConsensysToken");
        const MoonToken = artifacts.require("./MoonToken");
        const SeanToken = artifacts.require("./SeanToken");
        const FakeDai = artifacts.require("./FakeDai");
        const UniswapExchange = artifacts.require("./uniswap_exchange");
        const UniswapFactory = artifacts.require("./uniswap_factory");

        // Deploy ERC20 tokens
        deployer.deploy(SeanToken);
        deployer.deploy(MoonToken);
        deployer.deploy(ConsensysToken);

        // Start dependency pipeline
        // Deploy FakeDai
        deployer.deploy(FakeDai)
            // Deploy Uniswap Exchange template
            .then(() => deployer.deploy(UniswapExchange))

            // Deploy and initialize Uniswap Factory
            .then(() => deployer.deploy(UniswapFactory))
            .then(instance => instance.initializeFactory(UniswapExchange.address))

            // Deploy and initialize the main contract
            .then(() => deployer.deploy(CostAverageOrderBook, UniswapFactory.address))
            .then(instance => initializeCostAverageOrderBook(instance, FakeDai.address));
    }

    else {
        // Deploy the main contract
        deployer.deploy(CostAverageOrderBook, uniswapFactoryAddresses[network])
            .then(instance => initializeCostAverageOrderBook(instance, daiAddresses[network]));
    }
};
