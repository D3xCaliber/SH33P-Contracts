// SPDX-License-Identifier: P-P-P-PONZO!!!
pragma solidity ^0.7.4;

interface IPonzoMaBobberG1
{
    //function balancePriceBase(uint256 amount) external;
    //function balancePriceElite(uint256 amount) external;
    function pumpItPonzo (uint256 PUMPIT, address token) external;
    function pumpRooted(address token, uint256 amountToSpend) external;
    function sweepTheFloor() external;
    function zapEliteToBase(uint256 liquidity) external;
    function zapBaseToElite(uint256 liquidity) external;
    function wrapToElite(uint256 baseAmount) external;
    function unwrapElite(uint256 eliteAmount) external;
    function addLiquidity(address eliteOrBase, uint256 baseAmount) external;
    function removeLiquidity(address eliteOrBase, uint256 tokens) external;
    function buyRooted(address token, uint256 amountToSpend) external;
    function sellRooted(address token, uint256 amountToSpend) external;

}
