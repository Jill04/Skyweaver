 
var assert = require('assert');
const abi = require('ethereumjs-abi');

const ProxyContract = artifacts.require('ProxyCardNft.sol');
const Jungle = artifacts.require('JungleToken.sol');
const NFTcards = artifacts.require("NFTCards.sol");
const EternalStorageProxyJungle = artifacts.require('EternalStorageProxy.sol');
const EternalStorageProxyNft = artifacts.require('EternalStorageProxy.sol');



contract('EternalStorageProxy', ([_, proxyOwner, tokenOwner, anotherAccount]) => {
  let proxynft
  let proxytoken
  let v0_jungle
  let v0_nft
  let v1_jungle
  let v1_nft
  let impl_v0_jungle
  let impl_v0_nft
  
 
  beforeEach(async function () {
     proxynft = await EternalStorageProxyNft.new({ from: proxyOwner })
     proxytoken = await EternalStorageProxyJungle.new({ from : proxyOwner})
     v0_jungle = await Jungle.new();
     v0_nft = await NFTcards.new(v0_jungle.address,1627049295);
     impl_v0_nft = await NFTcards.at(proxynft.address);
     impl_v0_jungle = await Jungle.at(proxytoken.address); 
     accounts = await web3.eth.getAccounts();
  });

  //console.log(proxy.address + impl_v0.address);
  describe('upgrade and call', function () {
   
       const from = proxyOwner;

        it('upgrades to the given version', async function () {
          
          await proxytoken.upgradeTo('0', v0_jungle.address,{ from })
          await proxynft.upgradeTo('0',v0_nft.address,{ from })
          
          await impl_v0_jungle.initialize(proxyOwner,{from});
          var actual = await proxynft.version();
          var expected = 0
          assert.equal(actual, expected);

          var actual = await proxynft.implementation();
          var expected = v0_nft.address;
          assert.equal(actual, expected);

         
          await impl_v0_jungle.setNftCardAddress(impl_v0_nft.address,{from});
        })
      })
    }) 

