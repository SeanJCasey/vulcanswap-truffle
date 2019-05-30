// Steps for dev:
// 1. Deploy Factory contract
// 2. Deploy CostAverageOrderBook w/factory address
// 3. Deploy fake ERC20 contract
// 4. Deploy Exchange contract w/ fake ERC20 contract

const CostAverageOrderBook = artifacts.require("./CostAverageOrderBook");

module.exports = (deployer, network) => {
    const uniswapFactoryAddresses = {
        mainnet: "0xc0a47dFe034B400B47bDaD5FecDa2621de6c4d95",
        rinkeby: "0xf5D915570BC477f9B8D6C0E980aA81757A3AaC36"
    }

    // If not mainnet, deploy our ERC20 tokens
    if (network !== 'mainnet') {
        const ConsensysToken = artifacts.require("./ConsensysToken");
        const MoonToken = artifacts.require("./MoonToken");
        const SeanToken = artifacts.require("./SeanToken");

        deployer.deploy(SeanToken);
        deployer.deploy(MoonToken);
        deployer.deploy(ConsensysToken);
    }

    // If not mainnet or rinkeby, deploy uniswap mock contracts
    if (!(network in uniswapFactoryAddresses)) {
        const UniswapExchange = artifacts.require("./uniswap_exchange");
        const UniswapFactory = artifacts.require("./uniswap_factory");

        let exchangeTemplate;

        deployer.deploy(UniswapExchange)
            .then(instance => exchangeTemplate = instance)
            .then(() => deployer.deploy(UniswapFactory))
            .then(instance => instance.initializeFactory(exchangeTemplate.address))
            .then(() => deployer.deploy(CostAverageOrderBook, UniswapFactory.address, { value: 1000000000000000000 }));
    }
    else {
        deployer.deploy(CostAverageOrderBook, uniswapFactoryAddresses[network], { value: 1000000000000000000 });
    }
};
