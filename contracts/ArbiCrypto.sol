// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

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
		uint[] price;
		uint[] volume;
	}

	error AmountOutError(uint256);

	uint8[] bookIncrements = [5, 5, 5];

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

	function swapWithoutRevert(Pool calldata _pool, bool _zeroForOne, uint256 _amountIn) private returns (uint256) {
		bytes memory data = abi.encodeWithSignature("swap(address,bool,uint256,bool)", _pool, _zeroForOne, _amountIn, false);
		bytes memory returnData;
		bool success;

		assembly {
			let x := mload(0x40)
			success := delegatecall(gas(), address(), add(data, 0x20), mload(data), x, 0)
			let size := returndatasize()
			returnData := mload(0x40)
			mstore(0x40, add(returnData, and(add(add(size, 0x20), 0x1f), not(0x1f))))
			returndatacopy(returnData, 0, size)
		}

		if (!success) {
			if (returnData.length > 0) {
				assembly {
					let returnData_size := mload(returnData)
					revert(add(32, returnData), returnData_size)
				}
			} else {
				revert("Swap failed without an error message.");
			}
		}

		return abi.decode(returnData, (uint256));
	}

	function swapWithRevert(Pool calldata _pool, bool _zeroForOne, uint256 _amountIn) private returns (uint256 result) {
		bytes memory data = abi.encodeWithSignature("swap(address,bool,uint256,bool)", _pool, _zeroForOne, _amountIn, true);
		bool success;

		assembly {
			let x := mload(0x40)
			success := delegatecall(sub(gas(), 5000), address(), add(data, 0x20), mload(data), x, 0x20)
			result := mload(x)
		}

		require(!success, "Error, expected swap to revert.");

		return (result);
	}

	function swap(Pool calldata _pool, bool _zeroForOne, uint256 _amountIn, bool _revert) external onlyOwner returns (uint256 amountOut) {
		address[] memory path = new address[](2);
		if (_zeroForOne) {
			path[0] = _pool.token1;
			path[1] = _pool.token0;
		} else {
			path[0] = _pool.token0;
			path[1] = _pool.token1;
		}

		IERC20(path[0]).forceApprove(_pool.router, type(uint256).max);

		uint256 balanceBeforeSwap = IERC20(path[1]).balanceOf(address(this));

		if (_pool.poolType == PoolType.UNISWAP_V2) {
			ISwapRouterV2(_pool.router).swapExactTokensForTokensSupportingFeeOnTransferTokens(_amountIn, 0, path, address(this), block.timestamp + 60);
		} else if (_pool.poolType == PoolType.UNISWAP_V3) {
			ISwapRouterV3.ExactInputSingleParams memory params = ISwapRouterV3.ExactInputSingleParams(path[0], path[1], _pool.fee, address(this), _amountIn, 0, 0);
			ISwapRouterV3(_pool.router).exactInputSingle(params);
		// } else if (_pool.poolType == PoolType.UNISWAP_V3_OLD) {
		// 	ISwapRouterV3Old.ExactInputSingleParams memory params = ISwapRouterV3Old.ExactInputSingleParams(path[0], path[1], _pool.fee, address(this), block.timestamp + 60, _amountIn, 0, 0);
		// 	ISwapRouterV3Old(_pool.router).exactInputSingle(params);
		} else {
			revert("PoolType not supported");
		}

		amountOut = getTokenBalance(path[1], address(this)) - balanceBeforeSwap;

		if (_revert) {
			revert AmountOutError(amountOut);
		}
	}

	function getBook(Pool calldata _pool, bool _zeroForOne) external returns (Book memory) {
		IERC20(_pool.token0).forceApprove(_pool.router, type(uint256).max);
		IERC20(_pool.token1).forceApprove(_pool.router, type(uint256).max);

        uint8 tokenInDecimals;
		uint8 tokenOutDecimals;

        if (_zeroForOne) {
            tokenInDecimals = _pool.token1Decimals;
			tokenOutDecimals = _pool.token0Decimals;
        }
        else {
            tokenInDecimals = _pool.token0Decimals;
			tokenOutDecimals = _pool.token1Decimals;
        }

        uint256 amountIn = 10 ** tokenInDecimals;

        uint256 currentPrice;
		uint256 targetPrice;
		uint256 levelAmount;

		Book memory book;
		
		for (uint i = 0; i < bookIncrements.length; i++) {
			currentPrice = (amountIn) / ((swapWithRevert(_pool, _zeroForOne, amountIn) * (10 ** tokenOutDecimals)));
            targetPrice = (currentPrice * (100 + bookIncrements[i])) / 100;
			levelAmount = getAmountIn(_pool, _zeroForOne, targetPrice);

			book.price[i] = currentPrice;
			book.volume[i] = levelAmount;

			swapWithoutRevert(_pool, _zeroForOne, levelAmount);
		}

		return book;
	}

	function getAmountIn(Pool calldata _pool, bool _zeroForOne, uint256 _targetPrice) private returns (uint256) {
        uint256 bnDecimals;
        if (_zeroForOne) {
            bnDecimals = 10 ** _pool.token1Decimals;
        }
        else {
            bnDecimals = 10 ** _pool.token0Decimals;
        }
         
		uint256 left = 0;
		uint256 right = type(uint256).max / bnDecimals;
		uint8 tolerance = 1;

		while (((((right - left) * bnDecimals) / (right + left)) * 100) > tolerance) {
			uint256 mid = (right + left) / 2;
			uint256 out = swapWithRevert(_pool, _zeroForOne, mid);

			if (mid / out > _targetPrice) {
				left = mid;
			} else {
				right = mid;
			}
		}
		return (right + left) / 2;
	}
}
