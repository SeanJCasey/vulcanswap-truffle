module.exports = (deployer, network) => {
    if (!["mainnet", "rinkeby"].includes(network)) {
        const ConsensysToken = artifacts.require("./ConsensysToken");
        const FakeDai = artifacts.require("./FakeDai");
        const MoonToken = artifacts.require("./MoonToken");
        const SeanToken = artifacts.require("./SeanToken");

        // Deploy ERC20 tokens
        deployer.deploy(ConsensysToken);
        deployer.deploy(MoonToken);
        deployer.deploy(FakeDai);
        deployer.deploy(SeanToken);
    }
    else {
        console.log("Skipped migration: deploy mock tokens")
    }
};
