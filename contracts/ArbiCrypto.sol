// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Hardhat imports
import "hardhat/console.sol";

// Uniswap Functions
interface ISwapRouterV2 {
	function swapExactTokensForTokensSupportingFeeOnTransferTokens(
		uint amountIn,
		uint amountOutMin,
		address[] calldata path,
		address to,
		uint deadline
	) external;
}

interface ISwapRouterV3 {
	struct ExactInputSingleParams {
		address tokenIn;
		address tokenOut;
		uint24 fee;
		address recipient;
		uint amountIn;
		uint amountOutMinimum;
		uint160 sqrtPriceLimitX96;
	}

	function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint amountOut);
}

interface ISwapRouterV3Old {
	struct ExactInputSingleParams {
		address tokenIn;
		address tokenOut;
		uint24 fee;
		address recipient;
		uint deadline;
		uint amountIn;
		uint amountOutMinimum;
		uint160 sqrtPriceLimitX96;
	}

	function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint amountOut);
}

interface IERC20Extended is IERC20 {
	function decimals() external view returns (uint8);
}

contract ArbiCrypto is Ownable {
	using SafeERC20 for IERC20;

	enum PoolType {
		UNISWAP_V2,
		UNISWAP_V3,
		UNISWAP_V3_OLD
	}

	struct Pool {
		PoolType poolType;
		address poolAddress;
		address token0;
		address token1;
		uint8 token0Decimals;
		uint8 token1Decimals;
		uint24 fee;
		address router;
	}

	constructor() Ownable(address(msg.sender)) {}

	function withdrawAllOfToken(address _token) external onlyOwner {
		uint256 balance = IERC20(_token).balanceOf(address(this));
		IERC20(_token).transfer(owner(), balance);
	}

	function withdrawPartialOfToken(address _token, uint256 _amount) external onlyOwner {
		IERC20(_token).transfer(owner(), _amount);
	}

	function withdrawAllOfETH() external onlyOwner {
		payable(owner()).transfer(address(this).balance);
	}

	function withdrawPartialOfETH(uint256 _amount) external onlyOwner {
		payable(owner()).transfer(_amount);
	}

	function transferAllOfETH(address _recipient) external onlyOwner {
		payable(_recipient).transfer(address(this).balance);
	}

	function transferPartialOfETH(address _recipient, uint256 _amount) external onlyOwner {
		payable(_recipient).transfer(_amount);
	}

	function transferPartialOfToken(address _token, address _recipient, uint256 _amount) public onlyOwner {
		IERC20(_token).transfer(_recipient, _amount);
	}

	function transferAllOfToken(address _token, address _recipient) public onlyOwner {
		uint256 balance = IERC20(_token).balanceOf(address(this));
		IERC20(_token).transfer(_recipient, balance);
	}

	function getTokenBalance(address _token, address _address) public view returns (uint256) {
		return IERC20(_token).balanceOf(_address);
	}

	function getTokensBalances(address[] calldata _tokens, address _address) external view returns (uint256[] memory balances) {
		balances = new uint256[](_tokens.length);
		for (uint256 i = 0; i < _tokens.length; i++) {
			balances[i] = IERC20(_tokens[i]).balanceOf(_address);
		}
	}

	function getTokenDecimals(address _token) public view returns (uint8) {
		return IERC20Extended(_token).decimals();
	}

	function quote(Pool calldata _pool, bool _zeroForOne, uint256 _amountIn, bool _approve) public onlyOwner returns (uint256 amountOut, bool reverted) {
		bytes memory data = abi.encodeWithSignature(
			"swapInternal((uint8,address,address,address,uint8,uint8,uint24,address),bool,uint256,uint256,bool,bool)",
			_pool,
			_zeroForOne,
			_amountIn,
			0,
			true,
			_approve
		);

		bytes memory returnData;
		bytes memory errorData;
		bool success;

		assembly {
			let outPtr := mload(0x40)
			success := delegatecall(gas(), address(), add(data, 0x20), mload(data), outPtr, 0)
			let size := returndatasize()
			mstore(0x40, add(outPtr, and(add(size, 0x1f), not(0x1f))))
			if eq(size, 0x20) {
				mstore(outPtr, size)
				returndatacopy(add(outPtr, 0x20), 0, size)
				returnData := outPtr
				reverted := false
			}
			if iszero(eq(size, 0x20)) {
				if gt(size, 0x20) {
					returndatacopy(outPtr, 0, size)
					errorData := add(outPtr, 0x24)
				}
				if lt(size, 0x20) {
					let revertPtr := mload(0x40)
					mstore(revertPtr, 0x08c379a000000000000000000000000000000000000000000000000000000000)
					mstore(add(revertPtr, 0x04), 0x20) // String offset
					mstore(add(revertPtr, 0x24), 14) // Revert reason length
					mstore(add(revertPtr, 0x44), "Return size 0.")
					mstore(0x40, add(revertPtr, 0x64))
					//					revert(revertPtr, 0x64) // Revert data length is 4 bytes for selector and 3 slots of 0x20 bytes
					errorData := add(revertPtr, 0x24)
				}
				let returnZeroPtr := mload(0x40)
				mstore(returnZeroPtr, 0x20)
				mstore(add(returnZeroPtr, 0x20), 0)
				mstore(0x40, add(returnZeroPtr, 0x40))
				returnData := returnZeroPtr
				reverted := true
			}
		}

		if (reverted) {
			string memory revertReason = string(abi.encodePacked(errorData));
			console.log("delegateCall reverted. Reason: ", revertReason);
		}

		require(!success, "Error, expected swap to revert.");

		amountOut = abi.decode(returnData, (uint256));
	}

	function swap(Pool calldata _pool, bool _zeroForOne, uint256 _amountIn, uint256 _minAmountOut) public onlyOwner returns (bool success) {
		bytes memory data = abi.encodeWithSignature(
			"swapInternal((uint8,address,address,address,uint8,uint8,uint24,address),bool,uint256,uint256,bool,bool)",
			_pool,
			_zeroForOne,
			_amountIn,
			_minAmountOut,
			false,
			true
		);

		(success, ) = address(this).delegatecall(data);
	}

	function swapAndTransfer(
		Pool calldata _pool,
		bool _zeroForOne,
		uint256 _amountIn,
		uint256 _minAmountOut,
		address _recipient
	) public onlyOwner returns (bool success) {
		success = swap(_pool, _zeroForOne, _amountIn, _minAmountOut);
		if (success) {
			address tokenOut = _zeroForOne ? _pool.token0 : _pool.token1;
			transferAllOfToken(tokenOut, _recipient);
		}
	}

	function convertAndSwap(
		Pool calldata _convertPool,
		bool _zeroForOneConvert,
		Pool calldata _swapPool,
		bool _zeroForOneSwap,
		uint256 _amountIn,
		uint256 _minAmountOutConvert,
		uint256 _minAmountOutSwap
	) public onlyOwner returns (bool success) {
		success = swap(_convertPool, _zeroForOneConvert, _amountIn, _minAmountOutConvert);
		if (success) {
			address tokenOut = _zeroForOneConvert ? _swapPool.token0 : _swapPool.token1;
			uint256 balance = getTokenBalance(tokenOut, address(this));
			success = swap(_swapPool, _zeroForOneSwap, balance, _minAmountOutSwap);
		}
	}

	function convertSwapAndTransfer(
		Pool calldata _convertPool,
		bool _zeroForOneConvert,
		Pool calldata _swapPool,
		bool _zeroForOneSwap,
		uint256 _amountIn,
		uint256 _minAmountOutConvert,
		uint256 _minAmountOutSwap,
		address _recipient
	) public onlyOwner returns (bool success) {
		success = convertAndSwap(_convertPool, _zeroForOneConvert, _swapPool, _zeroForOneSwap, _amountIn, _minAmountOutConvert, _minAmountOutSwap);
		if (success) {
			address tokenOut = _zeroForOneSwap ? _swapPool.token1 : _swapPool.token0;
			transferAllOfToken(tokenOut, _recipient);
		}
	}

	function swapInternal(
		Pool calldata _pool,
		bool _zeroForOne,
		uint256 _amountIn,
		uint256 _minAmountOut,
		bool _revert,
		bool _approve
	) external onlyOwner returns (uint256 amountOut) {
		address[] memory path = new address[](2);

		path[0] = _zeroForOne ? _pool.token1 : _pool.token0;
		path[1] = _zeroForOne ? _pool.token0 : _pool.token1;

		if (_approve) {
			IERC20(path[0]).forceApprove(_pool.router, type(uint256).max);
		}

		address destAddress = address(this.owner());
		//address destAddress = address(this);

		uint256 balanceBeforeSwap = IERC20(path[1]).balanceOf(destAddress);

		if (_pool.poolType == PoolType.UNISWAP_V2) {
			ISwapRouterV2(_pool.router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
				_amountIn,
				_minAmountOut,
				path,
				destAddress,
				block.timestamp + 60
			);
		} else if (_pool.poolType == PoolType.UNISWAP_V3) {
			ISwapRouterV3.ExactInputSingleParams memory params = ISwapRouterV3.ExactInputSingleParams(
				path[0],
				path[1],
				_pool.fee,
				destAddress,
				_amountIn,
				0,
				0
			);
			ISwapRouterV3(_pool.router).exactInputSingle(params);
		} else if (_pool.poolType == PoolType.UNISWAP_V3_OLD) {
			ISwapRouterV3Old.ExactInputSingleParams memory params = ISwapRouterV3Old.ExactInputSingleParams(
				path[0],
				path[1],
				_pool.fee,
				destAddress,
				block.timestamp + 60,
				_amountIn,
				0,
				0
			);
			ISwapRouterV3Old(_pool.router).exactInputSingle(params);
		} else {
			revert("PoolType not supported");
		}

		amountOut = getTokenBalance(path[1], destAddress) - balanceBeforeSwap;

		if (amountOut == 0) {
			revert("No token received after swap");
		}

		if (_revert) {
			assembly {
				let ptr := mload(0x40)
				mstore(ptr, amountOut)
				revert(ptr, 32)
			}
		}
	}

	function getBook(Pool calldata _pool, bool _zeroForOne, uint16[] calldata _increments, uint256 _maxTokenOut) external onlyOwner returns (uint256[] memory) {
		IERC20(_pool.token0).forceApprove(_pool.router, type(uint256).max);
		IERC20(_pool.token1).forceApprove(_pool.router, type(uint256).max);

		console.log("bilancio token0: ", IERC20(_pool.token0).balanceOf(address(this)));
		console.log("bilancio token1: ", IERC20(_pool.token1).balanceOf(address(this)));
		console.log("bilancio token0 owner: ", IERC20(_pool.token0).balanceOf(address(this.owner())));
		console.log("bilancio token1 owner: ", IERC20(_pool.token1).balanceOf(address(this.owner())));
		console.log("allownace token 0", IERC20(_pool.token0).allowance(address(this), _pool.router));
		console.log("allownace token 1", IERC20(_pool.token1).allowance(address(this), _pool.router));
		console.log("allownace token 0 owner: ", IERC20(_pool.token0).allowance(address(this.owner()), _pool.router));
		console.log("allownace token 1 owner: ", IERC20(_pool.token1).allowance(address(this.owner()), _pool.router));

		uint8 tokenInDecimals = _zeroForOne ? _pool.token1Decimals : _pool.token0Decimals;
		uint8 tokenOutDecimals = _zeroForOne ? _pool.token0Decimals : _pool.token1Decimals;

		uint256[] memory book = new uint256[](_increments.length * 3 * 2);
		
		
		console.log("--->> STARTING ASKS BOOK");

		uint256 ticker = getTicker(_pool, _zeroForOne, false);
		console.log("ticker askBook: ", ticker);

		uint256 targetPrice;
		

		uint256 amountIn;
		uint256 amountOut;
		uint256 rightLimit = 0;

	




		for (uint i = 0; i < _increments.length; i++) {
			targetPrice = incrementPriceByPercent(ticker, _increments[i]);

			(amountIn, amountOut, rightLimit) = getAmountIn(_pool, !_zeroForOne, targetPrice, false, rightLimit);

			book[i * 3] = targetPrice;
			//			console.log("targetPrice: ", targetPrice);
			book[(i * 3) + 1] = amountIn;
			//			console.log("amountIn: ", amountIn);
			book[(i * 3) + 2] = amountOut;
			//			console.log("amountOut: ", amountOut);

			if (amountIn > _maxTokenOut * (10 ** tokenOutDecimals)) {
				break;
			}
		}


		console.log("--->> STARTING BIDS BOOK");

		ticker = getTicker(_pool, !_zeroForOne, false);
		console.log("ticker bidBook: ", ticker);

		rightLimit = 0;

		for (uint i = 0; i < _increments.length; i++) {
			targetPrice = incrementPriceByPercent(ticker, _increments[i]);

			(amountIn, amountOut, rightLimit) = getAmountIn(_pool, _zeroForOne, targetPrice, false, rightLimit);

			book[(i + _increments.length) * 3] = getPrice18Decimals(amountOut, amountIn, tokenInDecimals, tokenOutDecimals);
			book[((i + _increments.length) * 3) + 1] = amountOut;
			book[((i + _increments.length) * 3) + 2] = amountIn;

			if (amountOut > _maxTokenOut * (10 ** tokenOutDecimals)) {
				break;
			}
		}
		return book;
	}

	function getAmountIn(
		Pool calldata _pool,
		bool _zeroForOne,
		uint256 _targetPrice,
		bool _approve,
		uint256 _initialRight
	) internal returns (uint256 amountIn, uint256 amountOut, uint256 rightMax) {
		uint8 tokenInDecimals = _zeroForOne ? _pool.token1Decimals : _pool.token0Decimals;
		uint8 tokenOutDecimals = _zeroForOne ? _pool.token0Decimals : _pool.token1Decimals;
		uint256 left = 0;

		rightMax = _initialRight > 0 ? _initialRight : 10 ** tokenInDecimals;

		uint256 maxAmount = type(uint256).max / (10 ** tokenInDecimals);
		uint256 newRight;

		while (true) {
			if (rightMax > maxAmount) {
				rightMax = maxAmount;
				break;
			}

			// console.log("--- IN GET AMOUNT IN ---");
			// console.log("rightMax: ", rightMax);

			(uint256 out, ) = quote(_pool, _zeroForOne, rightMax, _approve);

			// console.log("quote: ", out);
			// console.log("----- FIRST END IN GET AMOUNT IN  ----");

			if (out == 1) {
				newRight = rightMax * 10;
				if (newRight / 10 != rightMax) {
					rightMax = maxAmount;
				} else {
					rightMax = newRight;
				}
			}

			uint256 price = getPrice18Decimals(rightMax, out, tokenOutDecimals, tokenInDecimals);

			// console.log("get price: ", price);
			// console.log("target price: ", _targetPrice);

			// console.log("---- SECOND END IN GET AMOUNT IN ---");

			if (price > _targetPrice || rightMax == maxAmount) {
				break;
			}

			newRight = rightMax * 10;
			if (newRight / 10 != rightMax) {
				rightMax = maxAmount;
			} else {
				rightMax = newRight;
			}
		}

		uint256 right = rightMax;

		uint256 tolerance = 10 ** (tokenInDecimals / 2);

		while (right - left > tolerance) {
			uint256 mid = left + (right - left) / 2;

			(amountOut, ) = quote(_pool, _zeroForOne, mid, _approve);
			uint256 price = getPrice18Decimals(mid, amountOut, tokenOutDecimals, tokenInDecimals);

			if (price > _targetPrice) {
				right = mid;
			} else {
				left = mid;
			}
		}
		amountIn = left + (right - left) / 2;
	}

	function getPrice18Decimals(uint256 tokenInAmount, uint256 tokenOutAmount, uint8 tokenInDecimals, uint8 tokenOutDecimals) private pure returns (uint256) {
		require(tokenInAmount != 0, "Token in amount cannot be zero");
		require(tokenOutAmount != 0, "Token out amount cannot be zero");

		uint256 scaleFactor = 10 ** 18;

		uint256 adjustFactor = 1;
		uint256 adjustedTokenInAmount = tokenInAmount;
		uint256 adjustedTokenOutAmount = tokenOutAmount;

		if (tokenInDecimals > tokenOutDecimals) {
			adjustFactor = 10 ** (tokenInDecimals - tokenOutDecimals);
			adjustedTokenInAmount = tokenInAmount * adjustFactor;
			require(adjustedTokenInAmount / adjustFactor == tokenInAmount, "Overflow in adjusting tokenIn decimals");
		} else if (tokenOutDecimals > tokenInDecimals) {
			adjustFactor = 10 ** (tokenOutDecimals - tokenInDecimals);
			adjustedTokenOutAmount = tokenOutAmount * adjustFactor;
			require(adjustedTokenOutAmount / adjustFactor == tokenOutAmount, "Overflow in adjusting tokenOut decimals");
		}

		uint256 scaledTokenInAmount = adjustedTokenInAmount * scaleFactor;
		require(scaledTokenInAmount / scaleFactor == adjustedTokenInAmount, "Overflow in scaling tokenIn decimals");

		uint256 scaledPrice = scaledTokenInAmount / adjustedTokenOutAmount;
		return scaledPrice;
	}

	function incrementPriceByPercent(uint256 price, uint256 percentIncrement) private pure returns (uint256 incrementedPrice) {
		uint256 incrementAmount = (price * percentIncrement) / 100;
		incrementedPrice = price + incrementAmount;
		require(incrementedPrice >= price, "Overflow occurred");

		return incrementedPrice;
	}

	function getTicker(Pool calldata _pool, bool _zeroForOne, bool _approve) public returns (uint256) {

		uint8 tokenInDecimals = _zeroForOne ? _pool.token1Decimals : _pool.token0Decimals;
		uint8 tokenOutDecimals = _zeroForOne ? _pool.token0Decimals : _pool.token1Decimals;

		uint256 amountIn = 1;
		uint256 amountOut = 0;
		bool reverted = true;
		bool prevReverted = true;
		uint256 ticker = 0;
		uint256 prevTicker = 0;

		while(amountIn < (type(uint256).max / 10)) {
			console.log("amountIn : ", amountIn);

			(amountOut, reverted) = quote(_pool, !_zeroForOne, amountIn, _approve);

			console.log("amountOut : ", amountOut);
			console.log("reverted : ", reverted);


			if (reverted == true && prevReverted == false) {
				break;
			}
			prevReverted = reverted;
			
			if (amountOut > 0) {
				ticker = getPrice18Decimals(amountIn, amountOut, tokenInDecimals, tokenOutDecimals);

				console.log("ticker : ", ticker);
				console.log("prevTicker : ", prevTicker);

				if ((ticker > incrementPriceByPercent(prevTicker, 1) && prevTicker != 0)|| ticker == prevTicker) break;
				prevTicker = ticker;
			}

			amountIn *= 10;
		}
		console.log("exited with ticker: ", prevTicker);
		return prevTicker;
	}
}
