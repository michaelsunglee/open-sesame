# frozen_string_literal: true
require 'net/http'

class WalletsController < ApplicationController
  EMPTY_BALANCE = "0x0000000000000000000000000000000000000000000000000000000000000000"

  def verify_signature
    address = request.params['address']
    signature = request.params['signature']

    message = request.params['message']
    public_key = VerifySignature.personal_recover(message, signature)
    result = Eth::Utils.public_key_to_address(public_key).downcase == address.downcase

    render plain: result.to_s
  end

  def validate
    address = request.params['address']
    contract_address = request.params['contract_address']
    gated_collection_id = request.params['collection_id']
    shopify_domain = request.params['shopify_domain']
    alchemy_key = ENV['ALCHEMY_KEY']

    url = URI.parse("https://eth-ropsten.alchemyapi.io/v2/#{alchemy_key}")
    req = Net::HTTP::Post.new(url.to_s)
    body = {
      jsonrpc: "2.0",
      method: "alchemy_getTokenBalances",
      params: [address, [contract_address]],
      id: 42
    }.to_json
    req.body = body
    res = Net::HTTP.start(url.host, url.port, :use_ssl => true) { |http|
      http.request(req)
    }

    response = JSON.parse(res.body)
    token_balances = response['result']['tokenBalances']
    token_balances.each do |balance|
      next unless balance['contractAddress'] == contract_address

      valid = balance['tokenBalance'] != EMPTY_BALANCE
      if valid
        @products = ProductFetcher.new.fetch_products_for(gated_collection_id)
        render 'valid', layout: false
        return
      end
    end

    render 'invalid', layout: false
  end
end
