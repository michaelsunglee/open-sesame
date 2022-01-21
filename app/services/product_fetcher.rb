require 'shopify_api'
require "graphql/client"
require "graphql/client/http"

class ProductFetcher

  def activate_session
    token = ENV['SHOP_TOKEN']
    shopify_session = ShopifyAPI::Session.new(
      domain: "online-bikecycle.myshopify.com",
      token: token,
      api_version: '2021-10'
    )
    ShopifyAPI::Base.activate_session(shopify_session)
  end

  def fetch_products_for(collection_id)
    activate_session
    client = ShopifyAPI::GraphQL.client

    query = client.parse <<-'GRAPHQL'
      query($collection_id: ID!) {
        collection(id: $collection_id) {
          id
          title
          products(first: 10){
            edges {
              node {
                id
                title
                onlineStoreUrl
                onlineStorePreviewUrl
                totalInventory
                featuredImage {
                  id
                  src
                }
              }
            }
          }
        }
      }
    GRAPHQL
    variables = {
      "collection_id": "gid://shopify/Collection/#{collection_id}",
    }
    result = client.query(query, variables: variables)
    result.data.collection.products.edges.to_a
  end
end