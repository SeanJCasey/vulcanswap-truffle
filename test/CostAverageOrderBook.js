const CostAverageOrderBook = artifacts.require('CostAverageOrderBook');

contract('CostAverageOrderBook', accounts => {

    let owner = accounts[0];
    let user1 = accounts[1];
    let user2 = accounts[2];
    // let remoteCaller = accounts[3];
    let randomMaliciousUser = accounts[4];

    const constructorAmount = web3.utils.toWei('0.1');

    // Order 1
    const orderId1 = 1;
    const contribAmount1 = web3.utils.toWei('5'); // using wei amount results in big num error
    const targetCurrency1 = '0xBd4Ac9375F7cfA025b9BA06A202c7abF24973c40';
    const frequency1 = 3600; // 1 hr
    const batches1 = 3;

    // Order 2
    const orderId2 = 2;
    const contribAmount2 = web3.utils.toWei('0.5'); // using wei amount results in big num error
    const targetCurrency2 = '0xBd4Ac9375F7cfA025b9BA06A202c7abF24973c40';
    const frequency2 = 86400; // 1 day
    const batches2 = 10;

    // Order 3
    const orderId3 = 3;
    const contribAmount3 = web3.utils.toWei('12.5786'); // using wei amount results in big num error
    const targetCurrency3 = '0xBd4Ac9375F7cfA025b9BA06A202c7abF24973c40';
    const frequency3 = 2592000; // 1 month
    const batches3 = 10;

    beforeEach(async () => {
        const uniswapFactoryAddress = '0xB48C962C1883D25ce93a6610A293c9dbaBf33F90';

        this.contract = await CostAverageOrderBook.new(uniswapFactoryAddress, {from: owner, value: constructorAmount });
    });

    describe('deploying a contract', () => {
        it('has some ETH', async () => {
            const contractBalance = await web3.eth.getBalance(this.contract.address);
            assert.equal(contractBalance, constructorAmount);
        });
    });

    describe('creating an order', () => {
        let tx;

        beforeEach(async () => {
            tx = await this.contract.createOrder(contribAmount1, targetCurrency1, frequency1, batches1, {from: user1, value: contribAmount1});
        })

        it('can get its target currency', async () => {
            const orderInfo = await this.contract.getOrder(orderId1);

            assert.equal(orderInfo.targetCurrency_, targetCurrency1);
        });

        it('fires an event', async () => {
            assert.equal(tx.logs[0].event, 'NewOrder');
        });
    });


    describe('retrieving orders', () => {
        beforeEach(async () => {
            await this.contract.createOrder(contribAmount1, targetCurrency1, frequency1, batches1, {from: user1, value: contribAmount1});
            await this.contract.createOrder(contribAmount2, targetCurrency2, frequency2, batches2, {from: user2, value: contribAmount2});
            await this.contract.createOrder(contribAmount3, targetCurrency3, frequency3, batches3, {from: user1, value: contribAmount3});
        });

        it('can get order count for an address', async () => {
            const orderCount = await this.contract.getOrderCountForAccount(user1);

            assert.equal(orderCount, 2)
        });

        it('can get all orders for an address', async () => {
            const orderCount = await this.contract.getOrderCountForAccount(user1);

            const orders = []
            for (let i = 0; i < orderCount; i++) {
                const order = await this.contract.getOrderForAccountIndex(user1, i);
                orders.push(order);
            }

            // User 1 should be the account of orders 1 and 3
            assert.equal(orders[0].id_, orderId1);
            assert.equal(orders[1].id_, orderId3);
        });

    });

    describe('cancel an order', () => {
        beforeEach(async () => {
            await this.contract.createOrder(contribAmount1, targetCurrency1, frequency1, batches1, {from: user1, value: contribAmount1});
        })

        it('sets order source balance to 0', async () => {
            await this.contract.cancelOrder(orderId1, {from: user1});

            const orderInfo = await this.contract.getOrder(orderId1);

            assert.equal(orderInfo.sourceCurrencyBalance_, 0);
        });

        it('fires an event', async () => {
            const tx = await this.contract.cancelOrder(orderId1, {from: user1});

            assert.equal(tx.logs[0].event, 'CancelOrder');
        });

        it('cannot be called by another user', async () => {
            expectThrow(this.contract.cancelOrder(orderId1, {from: randomMaliciousUser}));
        });
    });

    describe('remote caller', () => {
        it('can be changed by contract owner', async () => {
            await this.contract.setRemoteCaller(user1, {from: owner});
        });

        it('can only be changed by contract owner', async () => {
            // Is there an assert.fail?
            expectThrow(this.contract.setRemoteCaller(randomMaliciousUser, {from: randomMaliciousUser}));
        });

        it('can call executeDueConversions', async () => {
            await this.contract.executeDueConversions({from: owner});
        });

        it('only it can call executeDueConversions', async () => {
            expectThrow(this.contract.executeDueConversions({from: randomMaliciousUser}));
        });
    });
});

const expectThrow = async promise => {
    try {
        await promise
    } catch (error) {
        assert.exists(error)
        return
    }

    assert.fail('expected an error, but none was found')
}
