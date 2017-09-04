pragma solidity ^0.4.11;

import './stockExchange.sol';

contract EurUsdExchange is StockExchange {
    string public constant name = 'EUR/USD';

    function EurUsdExchange(){
        setUrl("json(https://www.bitstamp.net/api/v2/ticker/eurusd/).last");
    }
}

