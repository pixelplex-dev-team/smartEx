pragma solidity ^0.4.11;

import './stockExchange.sol';

contract EthUsdExchange is StockExchange {
    string public constant name = 'ETH/USD';

    function EthUsdExchange(){
        setUrl("json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c[0]");
    }
}

