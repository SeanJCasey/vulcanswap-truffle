module.exports = (deployer, network) => {
    const liveNetworks = ["mainnet", "rinkeby"];
    const nonDevNetworks = [
        ...liveNetworks,
        ...liveNetworks.map(liveNetwork => `${liveNetwork}-fork`)
    ];
    if (!nonDevNetworks.includes(network)) {
        const FakeDai = artifacts.require("./FakeDai");
        const FakeCDai = artifacts.require("./FakeCDai");
        const FakeCEther = artifacts.require("./FakeCEther");

        const FakeComptroller = artifacts.require("./FakeComptroller");
        const FakeCDaiInterestRateModel = artifacts.require("./FakeCDaiInterestRateModel");
        const FakeCEtherInterestRateModel = artifacts.require("./FakeCEtherInterestRateModel");
        // const FakePriceOracleFull = artifacts.require("./FakePriceOracle");

        // 1. Deploy Interest Models
        deployer.deploy(FakeCDaiInterestRateModel)
            .then(() => deployer.deploy(FakeCEtherInterestRateModel))

            // 2. Deploy Comptroller
            .then(() => deployer.deploy(FakeComptroller))

            // 3. Deploy Price Oracle
            // .then(() => deployer.deploy(FakePriceOracle, FakeDai.address))
            // .then(instance => instance.setPrice(FakeDai.address, 200 * 10**18))

            // 4. Deploy CErc20s
            .then(() => deployer.deploy(
                FakeCDai,
                FakeDai.address,
                FakeComptroller.address,
                FakeCDaiInterestRateModel.address
            ))

            // 5. Deploy CEther
            .then(() => deployer.deploy(
                FakeCEther,
                FakeComptroller.address,
                FakeCEtherInterestRateModel.address
            ))

            // 6. Initialize comptroller with cToken markets and settings
            .then(() => FakeComptroller.deployed())
            .then(instance => {
                instance._supportMarket(FakeCDai.address)
                instance._supportMarket(FakeCEther.address)
                // instance._setPriceOracle(FakePriceOracle.address)
                // instance._setMaxAssets(5)
            })
    }
    else {
        console.log("Skipped migration: deploy compound")
    }

};
