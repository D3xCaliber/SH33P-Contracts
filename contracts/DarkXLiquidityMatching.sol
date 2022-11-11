// SPDX-License-Identifier: J-J-J-JENGA!!!
pragma solidity ^0.7.4;

import "./DarkX.sol";
import "./IUniswapV2Router02.sol";
import "./IWrappedERC20.sol";
import "./IERC20.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Factory.sol";
import "./Owned.sol";
import "./TokensRecoverable.sol";
import "./MATIX.sol";
import "./SafeMath.sol";
import "./IWETH.sol";

/* ROOTKIT:
This receives DarkX from whereever
You can add ETH or MATIX and we'll match it with DarkX from here for you
Then you get the liquidity tokens back
All in one shot
Ready for staking
Cheaper than buying first!
*/
//Could probably do some part of the presale like this
contract DarkXLiquidityMatching is TokensRecoverable
{
    using SafeMath for uint256;

    DarkX immutable darkX;
    IUniswapV2Router02 immutable uniswapV2Router;
    IWrappedERC20 immutable liquidityTokenWrapper;
    MATIX immutable matiX;
    IWETH immutable weth;

    uint16 public liquidityPercentForUser = 5000; // 100% = 10000

    constructor(DarkX _darkX, IUniswapV2Router02 _uniswapV2Router, IWrappedERC20 _liquidityTokenWrapper, MATIX _matiX)
    {
        darkX = _darkX;
        uniswapV2Router = _uniswapV2Router;
        liquidityTokenWrapper = _liquidityTokenWrapper;
        matiX = _matiX;

        IWETH _weth = IWETH(_uniswapV2Router.WETH());
        weth = _weth;

        IERC20 _liquidityToken = _liquidityTokenWrapper.wrappedToken();
        _liquidityToken.approve(address(_liquidityTokenWrapper), uint256(-1));
        _darkX.approve(address(_uniswapV2Router), uint256(-1));
        _matiX.approve(address(_uniswapV2Router), uint256(-1));
        _weth.approve(address(_uniswapV2Router), uint256(-1));
        _weth.approve(address(_matiX), uint256(-1));

        require (IUniswapV2Factory(_uniswapV2Router.factory()).getPair(address(_darkX), address(_matiX)) == address(_liquidityToken), "Sanity");
    }

    receive() external payable
    {
        require (msg.sender == address(matiX));
    }

    function setLiquidityPercentForUser(uint16 _liquidityPercentForUser) public ownerOnly()
    {
        require (_liquidityPercentForUser <= 10000);

        liquidityPercentForUser = _liquidityPercentForUser;
    }

    function addLiquidityETH() public payable
    {
        uint256 amount = msg.value;
        require (amount > 0, "Zero amount");
        matiX.deposit{ value: amount }();

        uint256 remainingMatix = addMatixToLiquidity(amount);

        if (remainingMatix > 0) {
            matiX.withdraw(remainingMatix);
            (bool success,) = msg.sender.call{ value: remainingMatix }("");
            require (success, "Transfer failed");
        }
    }

    function addLiquidityWETH(uint256 amount) public
    {
        require (amount > 0, "Zero amount");
        weth.transferFrom(msg.sender, address(this), amount);
        matiX.depositTokens(amount);

        uint256 remainingMatix = addMatixToLiquidity(amount);

        if (remainingMatix > 0) {
            matiX.withdrawTokens(remainingMatix);
            weth.transfer(msg.sender, remainingMatix);
        }
    }

    function addLiquidityMATIX(uint256 amount) public
    {
        require (amount > 0, "Zero amount");
        matiX.transferFrom(msg.sender, address(this), amount);

        uint256 remainingMatix = addMatixToLiquidity(amount);

        if (remainingMatix > 0) {
            matiX.transfer(msg.sender, remainingMatix);
        }
    }

    function addMatixToLiquidity(uint256 amount) private returns (uint256 remainingMatix)
    {
        (,,uint256 liquidity) = uniswapV2Router.addLiquidity(address(darkX), address(matiX), darkX.balanceOf(address(this)), amount, 0, 0, address(this), block.timestamp);
        require (liquidity > 0, "No liquidity created (no available DarkX?)");
        liquidity = liquidity.mul(liquidityPercentForUser) / 10000;
        liquidityTokenWrapper.depositTokens(liquidity);
        liquidityTokenWrapper.transfer(msg.sender, liquidity);
        return matiX.balanceOf(address(this));
    }
}
