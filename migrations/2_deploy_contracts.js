// eslint-disable-next-line no-undef
const SmartHotel = artifacts.require('SmartHotel');

module.exports = async function(deployer, network, accounts) {
    await deployer.deploy(SmartHotel, '1', '100');
    //const hotel = await SmartHotel.deployed();
}