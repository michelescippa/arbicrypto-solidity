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

        
        const callData = arbicrypto.interface.encodeFunctionData("swap", [Pool, zeroForOne, BigInt(1 * (10 ** tokenInDecimals)), false, true]);
        const newBalance = BigInt(1000000 * (10 ** tokenInDecimals)); //ethers.MaxUint256;
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

        console.log("Tokens out: " + (ethers.getNumber(ethCall) / 10 ** tokenOutDecimals));
    });

    it("SwapWithoutRevert with stateDiff, testing with WETH/USDT", async function () {
        const poolContract = "0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852"
        const token0Contract = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
        const token0Decimals = 18;
        const token1Contract = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
        const token1Decimals = 6;
        const routerContract = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
        const poolFee = 500;
        const poolType = 0; //"UNISWAP_V3";
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

        
        const callData = arbicrypto.interface.encodeFunctionData("swapWithoutRevert", [Pool, zeroForOne,  BigInt(1 * (10 ** tokenInDecimals)), true]);
        const newBalance =  BigInt(1000000 * (10 ** tokenInDecimals)); //ethers.MaxUint256;
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

        console.log("Tokens out: " + (ethers.getNumber(ethCall) / 10 ** tokenOutDecimals));

        expect(ethers.getNumber(ethCall)).to.not.equal(0);
    });

    it("SwapWithRevert with stateDiff, testing with WETH/USDT", async function () {
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

        const amountIn = BigInt(8750000000000000000000);
        
     //   const callData = arbicrypto.interface.encodeFunctionData("swapWithRevert", [Pool, zeroForOne,  BigInt(100 * (10 ** tokenInDecimals)), true]);
        const callData = arbicrypto.interface.encodeFunctionData("swapWithRevert", [Pool, zeroForOne,  amountIn, true]);
        const newBalance =  BigInt(1000000 * (10 ** tokenInDecimals)); //ethers.MaxUint256;
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

        console.log("Tokens out: " + (ethers.getNumber(ethCall) / 10 ** tokenOutDecimals));

        expect(ethers.getNumber(ethCall)).to.not.equal(0);
    });

    it("GetBook with stateDiff, testing with WETH/USDT", async function () {
        // const poolContract = "0x11b815efB8f581194ae79006d24E0d814B7697F6"
        // const token0Contract = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
        // const token0Decimals = 18;
        // const token1Contract = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
        // const token1Decimals = 6;
        // const routerContract = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45";
        // const poolFee = 500;
        // const poolType = 1; //"UNISWAP_V3";
        // const compiler = "SOLIDITY";
        // const balanceSlot = 3;


        const poolContract = "0xa7BC6c09907fa2ded89F1c8D05374621cB1F88c5"
        const token0Contract = "0x6982508145454Ce325dDbE47a25d4ec3d2311933"
        const token0Decimals = 18;
        const token1Contract = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
        const token1Decimals = 6;
        const routerContract = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45";
        const poolFee = 3000;
        const poolType = 1; //"UNISWAP_V3";
        const compiler = "SOLIDITY";
        const token0BalanceSlot = 1;
        const token1BalanceSlot = 2;

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
        let tokenOutContract;
        let tokenInDecimals;
        let tokenOutDecimals;
        if (zeroForOne) {
            tokenInContract = token1Contract;
            tokenInDecimals = token1Decimals;
            tokenOutContract = token0Contract;
            tokenOutDecimals = token0Decimals;
        } else {
            tokenInContract = token0Contract;
            tokenInDecimals = token0Decimals;
            tokenOutContract = token1Contract;
            tokenOutDecimals = token1Decimals;
        }

        
      //  const callData = arbicrypto.interface.encodeFunctionData("getBook", [Pool, zeroForOne, [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100, 200, 300, 400], 100000000]);
        const callData = arbicrypto.interface.encodeFunctionData("getBook", [Pool, zeroForOne, [5, 10, 15], 100000000]);
 //       const newBalance = BigInt(ethers.MaxUint256.toString()) / BigInt(2);
        const newBalance = ethers.MaxUint256;
        const token0BalanceSlotHex = ethers.toBeHex(token0BalanceSlot, 32);
        const token1BalanceSlotHex = ethers.toBeHex(token1BalanceSlot, 32);
        const address = ethers.toBeHex(arbicrypto.target, 32);

        const token0Index = compiler == "SOLIDITY" ?  ethers.keccak256("0x" + address.substring(2) + token0BalanceSlotHex.substring(2)) :  ethers.keccak256("0x" + token0BalanceSlotHex.substring(2) + address.substring(2));
        const token1Index = compiler == "SOLIDITY"?  ethers.keccak256("0x" + address.substring(2) + token1BalanceSlotHex.substring(2)) : ethCaller.keccak256("0x" + token1BalanceSlotHex.substring(2) + address.substring(2));


        const params = [
            {
              from: owner.address,
              to: arbicrypto.target,
              data: callData,
            },
            "latest",
            {
                [tokenInContract]: {"stateDiff": {[token0Index]: ethers.toQuantity(newBalance)}},
       //         [tokenOutContract] : {"stateDiff": {[token1Index]: ethers.toQuantity(newBalance)}}
            }
          ];
        
        const ethCall = await network.provider.send("eth_call", params);

        const decodedResult = arbicrypto.interface.decodeFunctionResult("getBook", ethCall);

        console.log(decodedResult); // Questo dovrebbe essere il tuo oggetto Book

    //    console.log(ethCall);
    });

});