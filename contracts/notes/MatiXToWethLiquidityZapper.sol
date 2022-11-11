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

contract MatiXToWethLiquidityZapper is TokensRecoverable
{
    IUniswapV2Router02 immutable uniswapV2Router;
    IERC31337 immutable wrappedMatiXDarkX;
    IUniswapV2Pair matiXDarkX;
    IUniswapV2Pair wethDarkX;
    DarkX immutable DarkX;
    IWETH immutable weth;
    MATIX immutable matiX;

    constructor(IUniswapV2Router02 _uniswapV2Router, IERC31337 _wrappedMatiXDarkX, DarkX _DarkX)
    {
        uniswapV2Router = _uniswapV2Router;
        wrappedMatiXDarkX = _wrappedMatiXDarkX;
        DarkX = _DarkX;

        IUniswapV2Pair _matiXDarkX = IUniswapV2Pair(address(_wrappedMatiXDarkX.wrappedToken()));
        matiXDarkX = _matiXDarkX;

        IWETH _weth = IWETH(_uniswapV2Router.WETH());
        weth = _weth;

        MATIX  _matiX = MATIX(payable(_matiXDarkX.token0() == address(_DarkX) ? _matiXDarkX.token1() :_matiXDarkX.token0()));
        matiX = _matiX;

        wethDarkX = IUniswapV2Pair(IUniswapV2Factory(_uniswapV2Router.factory()).getPair(address(_weth), address(_DarkX)));

        _matiXDarkX.approve(address(_uniswapV2Router), uint256(-1));
        _matiX.approve(address(_uniswapV2Router), uint256(-1));
        _weth.approve(address(_uniswapV2Router), uint256(-1));
        _DarkX.approve(address(_uniswapV2Router), uint256(-1));

        require (_matiXDarkX.token0() == address(_DarkX) || _matiXDarkX.token1() == address(_DarkX), "Sanity");
        require (_matiXDarkX.token0() != address(_weth) && _matiXDarkX.token1() != address(_weth), "Sanity");
    }

    function go() public ownerOnly()
    {
        wrappedMatiXDarkX.sweepFloor(address(this));
        uint256 liquidity = matiXDarkX.balanceOf(address(this));
        require (liquidity > 0, "Nothing unwrapped");
        DarkXTransferGate gate = DarkXTransferGate(address(DarkX.transferGate()));
        gate.setUnrestricted(true);
        (uint256 amountDarkX, uint256 amountMatiX) = uniswapV2Router.removeLiquidity(address(DarkX), address(matiX), liquidity, 0, 0, address(this), block.timestamp);
        matiX.withdrawTokens(amountMatiX);
        (,,liquidity) = uniswapV2Router.addLiquidity(address(DarkX), address(weth), amountDarkX, amountMatiX, 0, 0, address(this), block.timestamp);
        require (liquidity > 0, "Nothing wrapped");
        wethDarkX.transfer(msg.sender, liquidity);
        uint256 balance = weth.balanceOf(address(this));
        if (balance > 0) { weth.transfer(msg.sender, balance ); }
        balance = matiX.balanceOf(address(this));
        if (balance > 0) { matiX.transfer(msg.sender, balance ); }
        balance = DarkX.balanceOf(address(this));
        if (balance > 0) { DarkX.transfer(msg.sender, balance ); }
        gate.setUnrestricted(false);
    }
}
