pragma solidity ^0.4.11;

import './stockExchange.sol';

contract EthBtcExchange is StockExchange {
    string public constant name = 'ETH/BTC';

    function EthBtcExchange(){
        setUrl("json(https://api.kraken.com/0/public/Ticker?pair=ETHXBT).result.XETHXXBT.c[0]");
    }
}

