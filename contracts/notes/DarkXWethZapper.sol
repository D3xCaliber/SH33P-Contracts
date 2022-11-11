// SPDX-License-Identifier: J-J-J-JENGA!!!
pragma solidity ^0.7.4;

import "./Owned.sol";
import "./IUniswapV2Router02.sol";
import "./IWETH.sol";
import "./DarkX.sol";
import "./DarkXTransferGate.sol";
import "./TokensRecoverable.sol";

contract DarkXWethZapper is TokensRecoverable
{
    function go(IWETH weth, DarkX DarkX, uint256 wethAmount, uint256 DarkXAmount, IUniswapV2Router02 uniswapV2Router)
        public ownerOnly()
    {
        DarkXTransferGate gate = DarkXTransferGate(address(DarkX.transferGate()));
        gate.setUnrestricted(true);
        weth.transferFrom(msg.sender, address(this), wethAmount);
        DarkX.transferFrom(msg.sender, address(this), DarkXAmount);
        weth.approve(address(uniswapV2Router), wethAmount);
        DarkX.approve(address(uniswapV2Router), DarkXAmount);
        uniswapV2Router.addLiquidity(address(weth), address(DarkX), wethAmount, DarkXAmount, wethAmount, DarkXAmount, msg.sender, block.timestamp);
        gate.setUnrestricted(false);
    }
}
