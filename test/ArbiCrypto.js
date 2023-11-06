const { expect } = require("chai");

describe("ArbiCrypto contract Unit Tests", function () {
    let arbicrypto;
    let owner;

    before(async function () {
        [owner] = await ethers.getSigners();
        const ArbiCrypto = await ethers.getContractFactory("ArbiCrypto");
        arbicrypto = await ArbiCrypto.deploy();
        await arbicrypto.waitForDeployment();
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

    it("Get balance with stateDiff, testing with USDT", async function () {
        const targetContract = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
        const compiler = "SOLIDITY";
        const balanceSlot = 2;
        const callData = arbicrypto.interface.encodeFunctionData("getTokenBalance", [targetContract, owner.address]);
        const newBalance = 123456; //ethers.MaxUint256;
        const balanceSlotHex = ethers.toBeHex(balanceSlot, 32);
        const address = ethers.toBeHex(owner.address, 32);

        const index = compiler == "SOLIDITY" ?  ethers.keccak256("0x" + address.substring(2) + balanceSlotHex.substring(2)) :  ethers.keccak256("0x" + balanceSlotHex.substring(2) + address.substring(2));

        const params = [
            {
              from: owner.address,
              to: arbicrypto.target,
              data: callData,
            },
            "latest",
            {[targetContract]: {"stateDiff": {[index]: ethers.toQuantity(newBalance)}} }
          ];
        
        const ethCall = await network.provider.send("eth_call", params);

        expect(ethers.getNumber(ethCall)).to.equal(newBalance);
    });

    it("Swap with stateDiff, testing with WETH/USDT", async function () {
        const poolContract = "0x11b815efB8f581194ae79006d24E0d814B7697F6"
        const token0Contract = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
        const token0Decimals = 18;
        const token1Contract = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
        const token1Decimals = 6;
        const routerContract = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45";
        const poolFee = 500;
        const poolType = 1; //"UNISWAP_V3";
        const compiler = "SOLIDITY";
        const balanceSlot = 3;

        const Pool = {
            poolType: poolType,
            poolAddress: poolContract,
            token0: token0Contract,
            token0Decimals: token0Decimals,
            token1: token1Contract,
            token1Decimals: token1Decimals,
            fee: poolFee,
            router: routerContract
        };

        const zeroForOne = false;

        let tokenInContract;
        let tokenInDecimals;
        let tokenOutDecimals;
        if (zeroForOne) {
            tokenInContract = token1Contract;
            tokenInDecimals = token1Decimals;
            tokenOutDecimals = token0Decimals;
        } else {
            tokenInContract = token0Contract;
            tokenInDecimals = token0Decimals;
            tokenOutDecimals = token1Decimals;
        }

        
        const callData = arbicrypto.interface.encodeFunctionData("swap", [Pool, zeroForOne, BigInt(10 ** tokenInDecimals), false]);
        const newBalance = BigInt(1000 * (10 ** tokenInDecimals)); //ethers.MaxUint256;
        const balanceSlotHex = ethers.toBeHex(balanceSlot, 32);
        const address = ethers.toBeHex(arbicrypto.target, 32);

        const index = compiler == "SOLIDITY" ?  ethers.keccak256("0x" + address.substring(2) + balanceSlotHex.substring(2)) :  ethers.keccak256("0x" + balanceSlotHex.substring(2) + address.substring(2));

        const params = [
            {
              from: owner.address,
              to: arbicrypto.target,
              data: callData,
            },
            "latest",
            {[tokenInContract]: {"stateDiff": {[index]: ethers.toQuantity(newBalance)}} }
          ];
        
        const ethCall = await network.provider.send("eth_call", params);

        console.log("Swap price: " + (ethers.getNumber(ethCall) / 10 ** tokenOutDecimals));
    });

});