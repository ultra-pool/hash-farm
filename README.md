Hash Farm
=========

HashFarm is intended to be a hashrate leaser.
HashFarm assure buyers to get the hashrate they paid for, and miners to be paid for the shares they share.

Miners just connect to us at www.hash.farm:3333

CGMiner is to old and buggy and doesn't work with our pool.
Miners must use CPUMiner or SGMiner.

Buyers send BTC on there HashFarm wallet, and create orders.
An order contains the url and the username/pasword it want to connect to,
the sum he wants to pay in BTC, and the price in BTC/MHs/Day for which workers will work.

He can precise a hashrate limit, to don't mine to fast (advise for new coins),

Installation
------------

### Prerequisite

- ruby 2.0+
- rails 4.0+
- postgresql 9.1+

### Installation

  bundle install

Configuration
-------------

In config/environments/, you can configure :

- server listening port (default: 3333)
