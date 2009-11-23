#!/usr/bin/ruby

require 'rubygems'
require 'activerecord'
require 'directed_edge'

ActiveRecord::Base.establish_connection(:adapter => 'mysql',
                                        :host => 'localhost',
                                        :username => 'examplestore',
                                        :password => 'password',
                                        :database => 'examplestore')

class Customer < ActiveRecord::Base
end

class Product < ActiveRecord::Base
end

class Purchase < ActiveRecord::Base
end

class ExampleStore
  def initialize
    @database = DirectedEdge::Database.new('examplestore', 'password')
  end

  def export_from_mysql

    # Use the handy Directed Edge XML exporter to collect store data up to this
    # point

    exporter = DirectedEdge::Exporter.new('examplestore.xml')

    # Loop through every customer in the database

    Customer.find(:all).each do |customer|

      # Create a new item in the Directed Edge export file with the ID "customer12345"

      item = DirectedEdge::Item.new(exporter.database, "customer#{customer.id}")

      # Mark this item as a customer with a tag

      item.add_tag('customer')

      # Find all of the purchases for the current customer
      
      purchases = Purchase.find(:all, :conditions => { :customer => customer.id })

      # For each purchase create a link from the customer to that item of the form
      # "product12345"

      purchases.each { |purchase| item.link_to("product#{purchase.product}") }

      # And now write the item to the export file

      exporter.export(item)
    end

    # Now go through all of the products creating items for them

    Product.find(:all).each do |product|

      # Here we'll also use the form "product12345" for our products

      item = DirectedEdge::Item.new(exporter.database, "product#{product.id}")

      # And mark it as a product with a tag

      item.add_tag('product')

      # And export it to the file

      exporter.export(item)
    end

    # We have to tell the exporter to clean up and finish up the file

    exporter.finish
  end

  # Imports the file exported from the export method to the Directed Edge database

  def import_to_directededge
    @database.import('examplestore.xml')
  end

  # Creates a new customer in the Directed Edge database that corresponds to the
  # given customer ID

  def create_customer(id)
    item = DirectedEdge::Item.new(@database, "customer#{id}")
    item.add_tag('customer')
    item.save
  end

  # Creates a new product in the Directed Edge database that corresponds to the
  # given product ID

  def create_product(id)
    item = DirectedEdge::Item.new(@database, "product#{id}")
    item.add_tag('product')
    item.save
  end

  # Notes in the Directed Edge database that customer_id purchased product_id

  def add_purchase(customer_id, product_id)
    item = DirectedEdge::Item.new(@database, "customer#{customer_id}")
    item.link_to("product#{product_id}")
    item.save
  end

  # Returns a list of product IDs related to the given product ID

  def related_products(product_id)
    item = DirectedEdge::Item.new(@database, "product#{product_id}")
    item.related(['product']).map { |product| product.sub('product', '').to_i }
  end

  # Returns a list of personalized recommendations for the given customer ID

  def personalized_recommendations(customer_id)
    item = DirectedEdge::Item.new(@database, "customer#{customer_id}")
    item.recommended(['product']).map { |product| product.sub('product', '').to_i }
  end
end

store = ExampleStore.new

# Export the contents of our MySQL database to XML

store.export_from_mysql

# Import that XML to the Directed Edge database

store.import_to_directededge

# Add a new customer

store.create_customer(500)

# Add a new product

store.create_product(2000)

# Set that user as having purchased that product

store.add_purchase(500, 2000)

# Find related products for the product with the ID 1 (in MySQL)

store.related_products(1).each do |product|
  puts "Related products for product 1: #{product}"
end

# Find personalized recommendations for the user with the ID 1 (in MySQL)

store.personalized_recommendations(1).each do |product|
  puts "Personalized recommendations for user 1: #{product}"
end
