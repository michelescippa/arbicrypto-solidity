const { expect } = require("chai");

describe("ArbiCrypto contract Unit Tests", function () {
    let arbicrypto;
    let owner;

    before(async function () {
        [owner] = await ethers.getSigners();
        const ArbiCrypto = await ethers.getContractFactory("ArbiCrypto");
        arbicrypto = await ArbiCrypto.deploy();
    });

    it("Get balance generic address, testing with USDT", async function () {
        const usdtTokenContract = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
        const walletAddress = "0x186f9CF0b2eDbFE275686E493388e1505D8Def63";
        const balance = await arbicrypto.getTokenBalance(usdtTokenContract, walletAddress);
        expect(balance).to.equal(0);
    });

    it("Get decimals, testing with USDT", async function () {
        const usdtTokenContract = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
        const decimals = await arbicrypto.getTokenDecimals(usdtTokenContract);
        expect(decimals).to.equal(6);
    });

});