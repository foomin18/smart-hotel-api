// eslint-disable-next-line no-undef
const SmartHotel = artifacts.require('SmartHotel');

require('chai')
.use(require('chai-as-promised'))
.should();

contract('SmartHotel', ([owner, customer]) => {
    let smartHotel;

    before(async () => {
        smartHotel = await SmartHotel.new(web3.utils.toWei('0.01', 'ether'), '100');
    })

    describe('SmartHotel deployment', async => {
        it('match name successfully', async () => {
            const name = await smartHotel.name();
            assert.equal(name, 'SmartHotel');
        })
        it('match price successfully', async () => {
            const price = await smartHotel.hotelTokenPrice();
            assert.equal(price, web3.utils.toWei('0.01', 'ether'), 'token price');
        })
        it('match timestamp successfully', async () => {
            const timestamp = await smartHotel.getUnixTimestamp(2023, 10, 27);
            assert.equal(timestamp, '1698364800', 'check timestamp');
        })
        it('buy hoteltoken successfully', async () => {
            await smartHotel.buyTokens('2', {from: customer, value: web3.utils.toWei('0.02', 'ether')});
            const tokenBalance = await smartHotel.getTokenBalance(customer);
            assert.equal(tokenBalance, '2', tokenBalance);
        })
        it('check appo', async () => {//トークン購入
            await smartHotel.buyTokens('2', {from: customer, value: web3.utils.toWei('0.02', 'ether')});  
            let balance = await smartHotel.getTokenBalance(customer);
            console.log('balance', balance);
            const timestamp = await smartHotel.getUnixTimestamp(2023, 12, 1); //デプロイした日よりあとにしないとだめ
            await smartHotel.bookAppo('0', 'foomin', timestamp, '3', {from: customer});  //予約
            balance = await smartHotel.getTokenBalance(customer);
            console.log('balance', balance);
            const appo = await smartHotel.showAppo('0', timestamp);
            console.log('name',appo);
            let range = await smartHotel.getAppoList('0', timestamp, 10);
            console.log('renge', range);
            await smartHotel.refundAppo('0', {from: customer}); //予約のキャンセル
            balance = await smartHotel.getTokenBalance(customer);
            console.log('balance', balance);
            range = await smartHotel.getAppoList('0', timestamp, 10);
            console.log('renge', range);
        })
        it('check in pass keyOpen', async () => {
            await smartHotel.buyTokens('2', {from: customer, value: web3.utils.toWei('0.02', 'ether')});  //トークン購入
            let balance = await smartHotel.getTokenBalance(customer);
            console.log('balance', balance);
            const timestamp = await smartHotel.getUnixTimestamp(2023, 12, 1);
            await smartHotel.bookAppo('0', 'foomin', timestamp, '3', {from: customer});  //予約
            balance = await smartHotel.getTokenBalance(customer);
            console.log('balance', balance);
            const appo = await smartHotel.showAppo('0', timestamp);
            console.log('name',appo);
            let range = await smartHotel.getAppoList('0', timestamp, '10');
            console.log('renge', range);
            await smartHotel.checkIn(timestamp, '0', {from: customer});  //チェックイン
            let booking = await smartHotel.isCheckedIn('0', {from: customer});
            console.log('booking',booking);
            let key = await smartHotel.isDoorOpen('0');
            console.log('key', key);
            await smartHotel.roomPassSet([1, 1, 1, 1, 1, 1], timestamp, '0', {from: customer});
            await smartHotel.keyOpen([1, 1, 1, 1, 1, 1], timestamp, '0', {from: customer});
            key = await smartHotel.isDoorOpen('0');
            console.log('key', key);
            await smartHotel.keyLock(timestamp, '0', {from: customer});
            key = await smartHotel.isDoorOpen('0');
            console.log('key', key);
            await smartHotel.checkOut(timestamp, '0', {from: customer});
        })
        it('change token price', async () => {
            await smartHotel.changeTokenPrice(web3.utils.toWei('0.02', 'ether'), {from: owner});
            let price = await smartHotel.hotelTokenPrice();
            assert.equal(price, web3.utils.toWei('0.02', 'ether'), 'token price');
            await smartHotel.buyTokens('2', {from: customer, value: web3.utils.toWei('0.04', 'ether')}); 
        })
    })
})