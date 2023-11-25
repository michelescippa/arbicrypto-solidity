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

    it("Swap with stateDiff, testing with WETH/DRAC", async function () {
        const poolContract = "0x1BB7941B8998edb59AdeA993833A7f0d19A601de"
        const token0Contract = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
        const token0Decimals = 18;
        const token1Contract = "0xc8A34E86C187830922f841985E376f412eE0088A";
        const token1Decimals = 18;
        const routerContract = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
        const poolFee = 500;
        const poolType = 0;
        const compiler = "SOLIDITY";
        const token0BalanceSlot = 3;
        const token1BalanceSlot = 6;

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

        let tokenInContract = zeroForOne ? token1Contract : token0Contract;
        let tokenInDecimals = zeroForOne ? token1Decimals : token0Decimals;
        let balanceSlot = zeroForOne ? token1BalanceSlot : token0BalanceSlot;

        const amountIn = BigInt(1 * (10 ** tokenInDecimals));
        
        const callData = arbicrypto.interface.encodeFunctionData("swap", [Pool, zeroForOne, amountIn, 0]);
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

        expect(ethers.getNumber(ethCall)).to.equal(1);
    });

    it("Quote with stateDiff, testing with WETH/DRAC", async function () {
        const poolContract = "0x1BB7941B8998edb59AdeA993833A7f0d19A601de"
        const token0Contract = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
        const token0Decimals = 18;
        const token1Contract = "0xc8A34E86C187830922f841985E376f412eE0088A";
        const token1Decimals = 18;
        const routerContract = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
        const poolFee = 500;
        const poolType = 0;
        const compiler = "SOLIDITY";
        const token0BalanceSlot = 3;
        const token1BalanceSlot = 6;

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

        const zeroForOne = true;

        let tokenInContract = zeroForOne ? token1Contract : token0Contract;
        let tokenInDecimals = zeroForOne ? token1Decimals : token0Decimals;
        let tokenOutDecimals = zeroForOne ? token0Decimals : token1Decimals;
        let balanceSlot = zeroForOne ? token1BalanceSlot : token0BalanceSlot;

       const amountIn = BigInt(1 * (10 ** tokenInDecimals));
        
        const callData = arbicrypto.interface.encodeFunctionData("quote", [Pool, zeroForOne,  amountIn, true]);
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
        console.log("Tokens out: " + (ethers.getBigInt(ethCall) / BigInt(10 ** tokenOutDecimals)));
        expect(ethers.getBigInt(ethCall)).to.not.equal(0);
    });

    it.only("GetBook with stateDiff, testing with WETH/DRAC", async function () {
        // WETH/DRAC
        // const poolContract = "0x1BB7941B8998edb59AdeA993833A7f0d19A601de"
        // const token0Contract = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
        // const token0Decimals = 18;
        // const token1Contract = "0xc8A34E86C187830922f841985E376f412eE0088A";
        // const token1Decimals = 18;
        // const routerContract = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
        // const poolFee = 0;
        // const poolType = 0;
        // const compiler = "SOLIDITY";
        // const token0BalanceSlot = 3;
        // const token1BalanceSlot = 6;

        // PEPE/USDT V2
        const poolContract = "0xB676b41F577812C5D5d755D22d302bc7A84Bb489"
        const token0Contract = "0x6982508145454Ce325dDbE47a25d4ec3d2311933"
        const token0Decimals = 18;
        const token1Contract = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
        const token1Decimals = 6;
        const routerContract = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
        const poolFee = 0;
        const poolType = 0;
        const compiler = "SOLIDITY";
        const token0BalanceSlot = 1;
        const token1BalanceSlot = 2;

        // PEEP/USDT V3
        // const poolContract = "0xa7BC6c09907fa2ded89F1c8D05374621cB1F88c5"
        // const token0Contract = "0x6982508145454Ce325dDbE47a25d4ec3d2311933"
        // const token0Decimals = 18;
        // const token1Contract = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
        // const token1Decimals = 6;
        // const routerContract = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45";
        // const poolFee = 3000;
        // const poolType = 1;
        // const compiler = "SOLIDITY";
        // const token0BalanceSlot = 1;
        // const token1BalanceSlot = 2;

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

        const zeroForOne = true;

        
        const callData = arbicrypto.interface.encodeFunctionData("getBook", [Pool, zeroForOne, [3, 5, 10], 10000]);
        const newBalance = BigInt(ethers.MaxUint256.toString()) / BigInt(1000000);
 //       const newBalance = ethers.MaxUint256;
        const token0BalanceSlotHex = ethers.toBeHex(token0BalanceSlot, 32);
        const token1BalanceSlotHex = ethers.toBeHex(token1BalanceSlot, 32);
        const address = ethers.toBeHex(arbicrypto.target, 32);

        const token0Index = compiler == "SOLIDITY" ?  ethers.keccak256("0x" + address.substring(2) + token0BalanceSlotHex.substring(2)) :  ethers.keccak256("0x" + token0BalanceSlotHex.substring(2) + address.substring(2));
        const token1Index = compiler == "SOLIDITY" ?  ethers.keccak256("0x" + address.substring(2) + token1BalanceSlotHex.substring(2)) : ethers.keccak256("0x" + token1BalanceSlotHex.substring(2) + address.substring(2));


        const params = [
            {
              from: owner.address,
              to: arbicrypto.target,
              data: callData,
            },
            "latest",
            {
                [token0Contract]: {"stateDiff": {[token0Index]: ethers.toQuantity(newBalance)}},
                [token1Contract]: {"stateDiff": {[token1Index]: ethers.toQuantity(newBalance)}}
            }
          ];
        
        const ethCall = await network.provider.send("eth_call", params);
        
    //    console.log(ethCall);

        const decodedResult = arbicrypto.interface.decodeFunctionResult("getBook", ethCall);

        console.log(decodedResult); // Questo dovrebbe essere il tuo oggetto Book

    //    console.log(ethCall);
    });

    it("Get Contract Tokens balance", async function () {
        const tokenOutContract = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
        const tokenInContract = "0xc8A34E86C187830922f841985E376f412eE0088A";

        const compiler = "SOLIDITY";
        const token0BalanceSlot = 3;
        const token1BalanceSlot = 6;


        
      //  const callData = arbicrypto.interface.encodeFunctionData("getBook", [Pool, zeroForOne, [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 60, 70, 80, 90, 100, 200, 300, 400], 100000000]);
        const callData = arbicrypto.interface.encodeFunctionData("getTokensBalances", [[tokenOutContract, tokenInContract], arbicrypto.target]);
        const newBalance = BigInt(ethers.MaxUint256.toString()) / BigInt(2);
 //       const newBalance = ethers.MaxUint256;
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
                [tokenOutContract]: {"stateDiff": {[token0Index]: ethers.toQuantity(newBalance)}},
                [tokenInContract] : {"stateDiff": {[token1Index]: ethers.toQuantity(newBalance)}}
            }
          ];
        
        const ethCall = await network.provider.send("eth_call", params);
        
//        console.log(ethCall);

        const decodedResult = arbicrypto.interface.decodeFunctionResult("getTokensBalances", ethCall);

        console.log(decodedResult); // Questo dovrebbe essere il tuo oggetto Book

    //    console.log(ethCall);
    });


});