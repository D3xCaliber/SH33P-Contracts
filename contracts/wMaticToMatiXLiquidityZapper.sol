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
import "./MATIX.sol";

contract WMaticToMatiXLiquidityZapper is TokensRecoverable
{
    IUniswapV2Router02 immutable uniswapV2Router;
    IERC31337 immutable wrappedWethDarkX;
    IUniswapV2Pair matiXDarkX;
    IUniswapV2Pair wethDarkX;
    DarkX immutable darkX;
    IWETH immutable weth;
    MATIX immutable matiX;

    constructor(IUniswapV2Router02 _uniswapV2Router, IERC31337 _wrappedWethDarkX, MATIX _matiX, DarkX _darkX)
    {
        uniswapV2Router = _uniswapV2Router;
        wrappedWethDarkX = _wrappedWethDarkX;
        matiX = _matiX;
        darkX = _darkX;

        IUniswapV2Pair _wethDarkX = IUniswapV2Pair(address(_wrappedWethDarkX.wrappedToken()));
        wethDarkX = _wethDarkX;

        IWETH _weth = IWETH(_uniswapV2Router.WETH());
        weth = _weth;

        matiXDarkX = IUniswapV2Pair(IUniswapV2Factory(_uniswapV2Router.factory()).getPair(address(_matiX), address(_darkX)));

        _wethDarkX.approve(address(_uniswapV2Router), uint256(-1));
        _matiX.approve(address(_uniswapV2Router), uint256(-1));
        _weth.approve(address(_matiX), uint256(-1));
        _weth.approve(address(_uniswapV2Router), uint256(-1));
        _darkX.approve(address(_uniswapV2Router), uint256(-1));

        require (_wethDarkX.token0() == address(_darkX) || _wethDarkX.token1() == address(_darkX), "Sanity");
        require (_wethDarkX.token0() == address(_weth) || _wethDarkX.token1() == address(_weth), "Sanity");
    }

    function WethToMatiX() public ownerOnly()
    {
        wrappedWethDarkX.sweepFloor(address(this));
        uint256 liquidity = wethDarkX.balanceOf(address(this));
        require (liquidity > 0, "Nothing unwrapped");
        DarkXTransferGate gate = DarkXTransferGate(address(darkX.transferGate()));
        gate.setUnrestricted(true);
        (uint256 amountDarkX, uint256 amountWeth) = uniswapV2Router.removeLiquidity(address(darkX), address(weth), liquidity, 0, 0, address(this), block.timestamp);
        matiX.depositTokens(amountWeth);
        (,,liquidity) = uniswapV2Router.addLiquidity(address(darkX), address(matiX), amountDarkX, amountWeth, 0, 0, address(this), block.timestamp);
        require (liquidity > 0, "Nothing wrapped");
        matiXDarkX.transfer(msg.sender, liquidity);
        uint256 balance = weth.balanceOf(address(this));
        if (balance > 0) { weth.transfer(msg.sender, balance ); }
        balance = matiX.balanceOf(address(this));
        if (balance > 0) { matiX.transfer(msg.sender, balance ); }
        balance = darkX.balanceOf(address(this));
        if (balance > 0) { darkX.transfer(msg.sender, balance ); }
        gate.setUnrestricted(false);
    }
}
