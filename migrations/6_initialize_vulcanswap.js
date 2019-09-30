const CostAverageOrderBook = artifacts.require("./CostAverageOrderBook");

module.exports = (deployer, network) => {
    const daiAddresses = {
        mainnet: "0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359",
        rinkeby: "0x2448eE2641d78CC42D7AD76498917359D961A783"
    };
    const cDaiAddresses = {
        mainnet: "0xf5dce57282a584d2746faf1593d3121fcac444dc",
        rinkeby: "0x6d7f0754ffeb405d23c51ce938289d4835be3b14"
    };
    const etherAddress = "0x0000000000000000000000000000000000000000";
    const cEtherAddresses = {
        mainnet: "0x4ddc2d193948926d02f9b1fe9e1daa0718270ed5",
        rinkeby: "0xd6801a1dffcd0a410336ef88def4320d6df1883e"
    };

    if (!(network in cDaiAddresses)) {
        // Add missing addresses
        const FakeDai = artifacts.require("./FakeDai");
        const FakeCDai = artifacts.require("./FakeCDai");
        const FakeCEther = artifacts.require("./FakeCEther");

        cDaiAddresses[network] = FakeCDai.address;
        cEtherAddresses[network] = FakeCEther.address;
        daiAddresses[network] = FakeDai.address;
    }

    deployer
        .then(() => CostAverageOrderBook.deployed())
        .then(instance => {
            // Add Eth as source currency
            const minEth = 0.1;
            const maxEth = 100;
            instance.createSourceCurrency(
                etherAddress,
                web3.utils.toWei(String(minEth), 'ether'),
                web3.utils.toWei(String(maxEth), 'ether')
            );

            // Associate with cEther
            instance.updateSourceCurrencyCToken(
                etherAddress,
                cEtherAddresses[network]
            );

            // Add Dai as source currency
            const minDai = 200;
            const maxDai = 20000;
            instance.createSourceCurrency(
                daiAddresses[network],
                web3.utils.toWei(String(minDai), 'ether'),
                web3.utils.toWei(String(maxDai), 'ether')
            );

            // Associate with cDai
            instance.updateSourceCurrencyCToken(
                daiAddresses[network],
                cDaiAddresses[network]
            );
        });
};
