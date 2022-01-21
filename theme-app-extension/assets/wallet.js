async function addWalletListener() {
  if (window.ethereum) {
    window.ethereum.on("accountsChanged", (accounts) => {
      if (accounts.length > 0) {
        document.getElementById("crypto-wallet-button").innerText = "Verify with: " + accounts[0]
      } else {
        document.getElementById("gated-products").style.display = "none";
        document.getElementById("crypto-wallet-button").innerText = "Connect Wallet"
      }
    })
  }
}

async function getCurrentWalletConnected() {
  if (window.ethereum) {
    const addressArray = await window.ethereum.request({
      method: "eth_accounts",
    });
    if (addressArray.length > 0) {
      document.getElementById("crypto-wallet-button").innerText = "Verify with: " + addressArray[0]
      document.getElementById("gated-products").style.display = "block";
      return addressArray[0];
    }
    return null;
  }
  return null;
};

async function connectWallet() {
  var connectedAddress = null;
  if (window.ethereum) {
    if (window.ethereum.selectedAddress == null) {
      const addressArray = await window.ethereum.request({
        method: "eth_requestAccounts",
      });
      const obj = {
        status: "^ Write a message above",
        address: addressArray[0],
      };
    } else {
      connectedAddress = window.ethereum.selectedAddress
      const requestId = Math.floor(Math.random() * 100000000)
      var message = "Please sign this message to verify ownership of the NFT. Request ID: " + requestId
      const signature = await window.ethereum.request({
        method: "personal_sign",
        params: [connectedAddress, message]
      })

      var params = `signature=${signature}&address=${connectedAddress}&message=${message}`
      const url='https://8a1a-2607-fea8-f4a3-9100-8445-c804-9b98-ca2b.ngrok.io/wallets/verify_signature';
      const req = new XMLHttpRequest();
      req.open("GET", url + "?" + params);
      req.send();
      req.onreadystatechange = (e) => {
        if (req.readyState == 4) {
          if (req.responseText == 'true') {
            fetchGatedView(connectedAddress)
          } else {
            console.log("you are not who you claim to be")
          }
        }
      }
    }
  }
};

async function fetchGatedView(connectedAddress) {
  const req = new XMLHttpRequest();
  var params = `contract_address=${contract_address}&collection_id=${gated_collection_id}&address=${connectedAddress}&shopify_domain=${shopify_domain}`
  const url='https://8a1a-2607-fea8-f4a3-9100-8445-c804-9b98-ca2b.ngrok.io/wallets/validate';
  req.open("GET", url+"?"+params);
  req.send();

  req.onreadystatechange = (e) => {
    if (req.readyState == 4) {
      var doc = document.getElementById("gated-products")
      doc.innerHTML = req.responseText
      document.getElementById("gated-products").style.display = "block"
    }
  }
}

const button = document.querySelector("#crypto-wallet-button");
button.addEventListener("click", connectWallet);
addWalletListener();

getCurrentWalletConnected().then(connected => {
  if (connected != null) {
    document.getElementById("gated-products").style.display = "block";
  } else {
    document.getElementById("gated-products").style.display = "none";
  }
});
