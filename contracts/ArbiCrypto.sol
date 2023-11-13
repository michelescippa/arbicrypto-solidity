// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

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

// interface ISwapRouterV3Old {
// 	struct ExactInputSingleParams {
// 		address tokenIn;
// 		address tokenOut;
// 		uint24 fee;
// 		address recipient;
// 		uint deadline;
// 		uint amountIn;
// 		uint amountOutMinimum;
// 		uint160 sqrtPriceLimitX96;
// 	}
// 	function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint amountOut);
// }

interface IERC20Extended is IERC20 {
	function decimals() external view returns (uint8);
}

interface ArbiSwap {
	function swap(ArbiCrypto.Pool calldata _pool, bool _zeroForOne, uint256 _amountIn, bool _revert) external returns (uint256);
}

// Hardhat imports
import "hardhat/console.sol";

contract ArbiCrypto is Ownable {
	using SafeERC20 for IERC20;

	enum PoolType {
		UNISWAP_V2,
		UNISWAP_V3
		//		UNISWAP_V3_OLD
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

	struct Book {
		uint[] askprice;
		uint[] askvolume;
		uint[] bidprice;
		uint[] bidvolume;
	}

	constructor() Ownable(address(msg.sender)) {}

	function withdrawToken(address _token) external onlyOwner {
		uint256 balance = IERC20(_token).balanceOf(address(this));
		IERC20(_token).transfer(owner(), balance);
	}

	function withdrawETH() external onlyOwner {
		payable(owner()).transfer(address(this).balance);
	}

	function getTokenBalance(address _token, address _address) public view returns (uint256) {
		return IERC20(_token).balanceOf(_address);
	}

	function getTokenDecimals(address _token) public view returns (uint8) {
		return IERC20Extended(_token).decimals();
	}

	function swapWithoutRevert(Pool calldata _pool, bool _zeroForOne, uint256 _amountIn, bool _approve) public returns (uint256) {
		bytes memory data = abi.encodeWithSignature(
			"swap((uint8,address,address,address,uint8,uint8,uint24,address),bool,uint256,bool,bool)",
			_pool,
			_zeroForOne,
			_amountIn,
			false,
			_approve
		);

		bytes memory returnData;
		bool success;

		assembly {
			let outPtr := mload(0x40)
			success := delegatecall(gas(), address(), add(data, 0x20), mload(data), outPtr, 0)
			let size := returndatasize()
			mstore(0x40, add(outPtr, and(add(size, 0x1f), not(0x1f))))
			mstore(outPtr, size)
			returndatacopy(add(outPtr, 0x20), 0, size)
			returnData := outPtr
		}

		//	revert("prova test");
		require(success, "Swap failed!");

		return abi.decode(returnData, (uint256));
	}

	function swapWithRevert(Pool calldata _pool, bool _zeroForOne, uint256 _amountIn, bool _approve) public returns (uint256) {
		bytes memory data = abi.encodeWithSignature(
			"swap((uint8,address,address,address,uint8,uint8,uint24,address),bool,uint256,bool,bool)",
			_pool,
			_zeroForOne,
			_amountIn,
			true,
			_approve
		);

		bytes memory returnData;
		bool success;

		assembly {
			let outPtr := mload(0x40)
			success := delegatecall(gas(), address(), add(data, 0x20), mload(data), outPtr, 0)
			let size := returndatasize()
			mstore(0x40, add(outPtr, and(add(size, 0x1f), not(0x1f))))
			if gt(size, 0) {
				if gt(size, 0x20) {
					revert(outPtr, size)
				}
				mstore(outPtr, size)
				returndatacopy(add(outPtr, 0x20), 0, size)
				returnData := outPtr
			}
			if eq(size, 0) {
				let revertPtr := mload(0x40)
				mstore(revertPtr, 0x08c379a000000000000000000000000000000000000000000000000000000000)
				mstore(add(revertPtr, 0x04), 0x20) // String offset
				mstore(add(revertPtr, 0x24), 14) // Revert reason length
				mstore(add(revertPtr, 0x44), "Return size 0.")
				revert(revertPtr, 0x64) // Revert data length is 4 bytes for selector and 3 slots of 0x20 bytes
			}
		}

		require(!success, "Error, expected swap to revert.");

		return abi.decode(returnData, (uint256));
	}

	function swap(Pool calldata _pool, bool _zeroForOne, uint256 _amountIn, bool _revert, bool _approve) external onlyOwner returns (uint256 amountOut) {
		address[] memory path = new address[](2);
		if (_zeroForOne) {
			path[0] = _pool.token1;
			path[1] = _pool.token0;
		} else {
			path[0] = _pool.token0;
			path[1] = _pool.token1;
		}

		if (_approve) {
			IERC20(path[0]).forceApprove(_pool.router, type(uint256).max);
		}

		uint256 balanceBeforeSwap = IERC20(path[1]).balanceOf(address(this));

		if (_pool.poolType == PoolType.UNISWAP_V2) {
			ISwapRouterV2(_pool.router).swapExactTokensForTokensSupportingFeeOnTransferTokens(_amountIn, 0, path, address(this), block.timestamp + 60);
		} else if (_pool.poolType == PoolType.UNISWAP_V3) {
			ISwapRouterV3.ExactInputSingleParams memory params = ISwapRouterV3.ExactInputSingleParams(
				path[0],
				path[1],
				_pool.fee,
				address(this),
				_amountIn,
				0,
				0
			);
			ISwapRouterV3(_pool.router).exactInputSingle(params);
		} else {
			revert("PoolType not supported");
		}

		amountOut = getTokenBalance(path[1], address(this)) - balanceBeforeSwap;

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

	function getBook(Pool calldata _pool, bool _zeroForOne, uint16[] calldata _increments, uint256 _maxTokenOut) external returns (Book memory) {
		console.log("gas residuo prima della transazione", gasleft());

		IERC20(_pool.token0).forceApprove(_pool.router, type(uint256).max);
		IERC20(_pool.token1).forceApprove(_pool.router, type(uint256).max);


		// AsksBook

		uint8 tokenInDecimals;
		uint8 tokenOutDecimals;

		if (_zeroForOne) {
			tokenInDecimals = _pool.token1Decimals;
			tokenOutDecimals = _pool.token0Decimals;
		} else {
			tokenInDecimals = _pool.token0Decimals;
			tokenOutDecimals = _pool.token1Decimals;
		}

		uint256 amountIn = 10 ** tokenInDecimals;
		uint256 amountOut = swapWithRevert(_pool, _zeroForOne, amountIn, false);

		console.log("amountOut:", amountOut);

		uint256 ticker = getPrice(amountIn, amountOut, tokenInDecimals, tokenOutDecimals);

		console.log("ticker: ", ticker);

		uint256 targetPrice;
		uint256 rightLimit = 0;

		Book memory book;

		book.askprice = new uint256[](_increments.length);
		book.askvolume = new uint256[](_increments.length);
		
		for (uint i = 0; i < _increments.length; i++) {
			targetPrice = incrementPriceByPercent(ticker, _increments[i]);

			(amountIn, amountOut, rightLimit) = getAmountIn(_pool, _zeroForOne, targetPrice, false, rightLimit);

			book.askprice[i] = targetPrice;
			book.askvolume[i] = amountIn;

			if (amountOut >  _maxTokenOut * (10 ** tokenOutDecimals)) {
				break;
			}
		}

		// // BidsBook

		// if (_zeroForOne) {
		// 	tokenInDecimals = _pool.token0Decimals;
		// 	tokenOutDecimals = _pool.token1Decimals;
		// } else {
		// 	tokenInDecimals = _pool.token1Decimals;
		// 	tokenOutDecimals = _pool.token0Decimals;
		// }

		// amountIn = 10 ** tokenInDecimals;
		// amountOut = swapWithRevert(_pool, !_zeroForOne, amountIn, false);
		// ticker = getPrice(amountIn, amountOut, tokenInDecimals, tokenOutDecimals);
		
		// rightLimit = 0;

		// book.bidprice = new uint256[](_increments.length);
		// book.bidvolume = new uint256[](_increments.length);

		// for (uint i = 0; i < _increments.length; i++) {
		// 	targetPrice = incrementPriceByPercent(ticker, _increments[i]);

		// 	(amountIn, amountOut, rightLimit) = getAmountIn(_pool, !_zeroForOne, targetPrice, false, rightLimit);

		// 	book.bidprice[i] = targetPrice;
		// 	book.bidvolume[i] = amountIn;

		// 	if (amountIn >  _maxTokenOut * (10 ** tokenInDecimals)) {
		// 		break;
		// 	}
		// }



		console.log("gas resido finale:", gasleft());
		return book;
	}

	function getAmountIn(
		Pool calldata _pool,
		bool _zeroForOne,
		uint256 _targetPrice,
		bool _approve,
		uint256 _initialRight
	) private returns (uint256 amountIn, uint256 amountOut, uint256 rightMax) {
		uint8 tokenInDecimals = _zeroForOne ? _pool.token1Decimals : _pool.token0Decimals;
		uint8 tokenOutDecimals = _zeroForOne ? _pool.token0Decimals : _pool.token1Decimals;
		uint256 left = 0;

		if (_initialRight > 0) {
			rightMax = _initialRight;
		}
		else {
			rightMax = 10 ** tokenInDecimals;
		}
		
		uint256 maxAmount = type(uint256).max / (10 ** tokenInDecimals);

		while (true) {
			if (rightMax > maxAmount) {
				rightMax = maxAmount;
				break;
			}

			uint256 out = swapWithRevert(_pool, _zeroForOne, rightMax, _approve);
			uint256 price = getPrice(rightMax, out, tokenInDecimals, tokenOutDecimals);

			if (price > _targetPrice || rightMax == maxAmount) {
				break;
			}

			uint256 newRight = rightMax * 10;
			if (newRight / 10 != rightMax) {
				rightMax = maxAmount;
			} else {
				rightMax = newRight;
			}
		}

		uint256 right = rightMax;

		uint256 tolerance = 10 ** tokenInDecimals;

		
		while (right - left > tolerance) {
			uint256 mid = left + (right - left) / 2;

			amountOut = swapWithRevert(_pool, _zeroForOne, mid, _approve);
			uint256 price = getPrice(mid, amountOut, tokenInDecimals, tokenOutDecimals);

			if (price > _targetPrice) {
				right = mid;
			} else {
				left = mid;
			}
		}
		amountIn = left + (right - left) / 2;
	}

	function getPrice(
		uint256 tokenInAmount,
		uint256 tokenOutAmount,
		uint8 tokenInDecimals,
		uint8 tokenOutDecimals
	) internal pure returns (uint256 priceInTokenIn) {
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
		priceInTokenIn = scaledPrice / adjustFactor;
		return priceInTokenIn;
	}

	function incrementPriceByPercent(uint256 price, uint256 percentIncrement) internal pure returns (uint256 incrementedPrice) {
		uint256 incrementAmount = (price * percentIncrement) / 100;
		incrementedPrice = price + incrementAmount;
		require(incrementedPrice >= price, "Overflow occurred");

		return incrementedPrice;
	}
}
