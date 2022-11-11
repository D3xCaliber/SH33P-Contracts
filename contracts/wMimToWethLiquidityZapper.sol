// SPDX-License-Identifier: J-J-J-JENGA!!!
pragma solidity ^0.7.4;

import "./Owned.sol";
import "./TokensRecoverable.sol";
import "./DarkX.sol";
import "./IERC31337.sol";
import "./IUniswapV2Router02.sol";
import "./IWETH.sol";
import "./IUniswapV2Pair.sol";
import "./IERC20.sol";
import "./DarkXTransferGate.sol";

import "./UniswapV2Library.sol";

contract WmimToWethLiquidityZapper is TokensRecoverable
{
    IUniswapV2Router02 immutable uniswapV2Router;
    IERC31337 immutable wrappedWmimDarkX;
    IUniswapV2Pair wmimDarkX;
    IUniswapV2Pair wethDarkX;
    DarkX immutable darkX;
    IWETH immutable weth;
    IERC20 immutable wmim;

    constructor(IUniswapV2Router02 _uniswapV2Router, IERC31337 _wrappedWmimDarkX, DarkX _darkX)
    {
        uniswapV2Router = _uniswapV2Router;
        wrappedWmimDarkX = _wrappedWmimDarkX;
        darkX = _darkX;

        IUniswapV2Pair _wmimDarkX = IUniswapV2Pair(address(_wrappedWmimDarkX.wrappedToken()));
        wmimDarkX = _wmimDarkX;

        IWETH _weth = IWETH(_uniswapV2Router.WETH());
        weth = _weth;

        IERC20 _wmim = IERC20(_wmimDarkX.token0() == address(_darkX) ? _wmimDarkX.token1() : _wmimDarkX.token0());
        wmim = _wmim;

        wethDarkX = IUniswapV2Pair(IUniswapV2Factory(_uniswapV2Router.factory()).getPair(address(_weth), address(_darkX)));

        _wmimDarkX.approve(address(_uniswapV2Router), uint256(-1));
        _wmim.approve(address(_uniswapV2Router), uint256(-1));
        _weth.approve(address(_uniswapV2Router), uint256(-1));
        _darkX.approve(address(_uniswapV2Router), uint256(-1));

        require (_wmimDarkX.token0() == address(_darkX) || _wmimDarkX.token1() == address(_darkX), "Sanity");
        require (_wmimDarkX.token0() != address(_weth) && _wmimDarkX.token1() != address(_weth), "Sanity");
    }

    function go() public ownerOnly()
    {
        wrappedWmimDarkX.sweepFloor(address(this));
        uint256 liquidity = wmimDarkX.balanceOf(address(this));
        require (liquidity > 0, "Nothing unwrapped");
        DarkXTransferGate gate = DarkXTransferGate(address(darkX.transferGate()));
        gate.setUnrestricted(true);
        (uint256 amountDarkX, uint256 amountWmim) = uniswapV2Router.removeLiquidity(address(darkX), address(wmim), liquidity, 0, 0, address(this), block.timestamp);
        address[] memory path = new address[](2);
        path[0] = address(wmim);
        path[1] = address(weth);
        (uint256[] memory amounts) = uniswapV2Router.swapExactTokensForTokens(amountWmim, 0, path, address(this), block.timestamp);
        (,,liquidity) = uniswapV2Router.addLiquidity(address(darkX), address(weth), amountDarkX, amounts[1], 0, 0, address(this), block.timestamp);
        require (liquidity > 0, "Nothing wrapped");
        wethDarkX.transfer(msg.sender, liquidity);
        uint256 balance = weth.balanceOf(address(this));
        if (balance > 0) { weth.transfer(msg.sender, balance ); }
        balance = wmim.balanceOf(address(this));
        if (balance > 0) { wmim.transfer(msg.sender, balance ); }
        balance = darkX.balanceOf(address(this));
        if (balance > 0) { darkX.transfer(msg.sender, balance ); }
        gate.setUnrestricted(false);
    }
}
