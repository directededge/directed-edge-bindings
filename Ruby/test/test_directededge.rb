require 'helper'
require 'pp'

# Defines a multithreaded "each"

module Enumerable
  def concurrently
    map {|item| Thread.new { yield item }}.each {|t| t.join }
  end
end

class TestDirectedEdge < Test::Unit::TestCase
  def setup
    user = ENV['DIRECTEDEDGE_TEST_DB']
    pass = ENV['DIRECTEDEDGE_TEST_PASS']
    @database = DirectedEdge::Database.new(user, pass)
    @database.import(File.expand_path('../../../testdb.xml', __FILE__))
  end

  def test_updatejob
    job = DirectedEdge::UpdateJob.new(@database, :replace)

    job.item('test_product') do |product|
      product.tags.add('product')
      product[:name] = 'Test Product'
    end

    second_user = job.item('test_user_2')

    job.item('test_user_1') do |first_user|
      first_user.tags.add 'user'
      first_user[:name] = 'Test User'
      first_user.links.add(second_user)
      first_user.links.add('test_product', :weight => 5)
    end

    job.run

    user = DirectedEdge::Item.new(@database, 'test_user_1')
    product = DirectedEdge::Item.new(@database, 'test_product')

    assert(user.tags.include?('user'))
    assert_equal('Test User', user['name'])

    assert(user.links.include?('test_product'))
    assert(user.links.include?('test_user_2'))
    assert(user.links.cached_data.include?(DirectedEdge::Link.new('test_product', :weight => 5)))

    assert(product.tags.include?('product'))
    assert_equal('Test Product', product['name'])
  end

  def test_updatejob_update
    job = DirectedEdge::UpdateJob.new(@database, :update)
    job.item('Foo') { |item| item['name'] = 'Bar' }
    job.run
    
    item = DirectedEdge::Item.new(@database, 'Foo')
    assert_equal('Bar', item['name'])
  end

  def test_items
    first_item = DirectedEdge::Item.new(@database, 'test_1')
    first_item.save

    second_item = DirectedEdge::Item.new(@database, 'test_2')
    second_item.links.add(first_item)
    second_item.save

    third_item = DirectedEdge::Item.new(@database, 'test_3')
    third_item.links.add(first_item)
    third_item.links.add(second_item)
    third_item.tags.add('test_tag')
    third_item.save

    assert_equal('test_1', first_item.id)

    # Make sure that the number of tags / links for the first item is zero

    assert_equal(0, first_item.links.length)
    assert_equal(0, first_item.tags.length)

    # Link the first item to the second item and make sure it worked

    first_item.links.add(second_item)
    first_item.save
    assert_equal(1, first_item.links.length)

    # Make sure that the number of tags for the second item is zero and that
    # there is a link to the second item

    assert_equal(1, second_item.links.length)
    assert_equal(0, second_item.tags.length)

    # Make sure that the third item is linked to both the first and second items

    assert_equal(2, third_item.links.length)
    assert(third_item.links.include?(first_item))
    assert(third_item.links.include?(second_item))

    # Make sure that the first and second items show up in the related items for
    # the third item

    assert(third_item.related.include?(first_item.to_s))
    assert(third_item.related.include?(second_item.to_s))

    # Since linked items are excluded from recommendations, nothing should show
    # up in the recommended items for the third item.

    assert_equal(0, third_item.recommended.length)
    assert_equal(1, second_item.recommended.length)
    assert_equal(0, second_item.recommended(:tags => 'unknown_tag').length)
    assert_equal(third_item.to_s, first_item.recommended(:tags => 'test_tag').first.to_s)

    # Remove the link from the second item and assure that it was removed

    second_item.links.remove(first_item)
    second_item.save

    assert_equal(0, second_item.links.length)

    # Remove the links from the third item and assure that they were removed

    third_item.links.remove(first_item)
    third_item.links.remove(second_item)
    third_item.save

    assert_equal(0, third_item.links.length)

    # Now make sure that those items no longer show up as related items

    assert(!third_item.related.include?(first_item.to_s))
    assert(!third_item.related.include?(second_item.to_s))

    # Test item removal

    assert_equal(1, first_item.links.length)

    second_item.destroy
    first_item.load

    assert_equal(0, first_item.links.length)
  end

  def test_tags
    item = DirectedEdge::Item.new(@database, 'customer1')
    item.tags.add('dude')
    assert(item.tags.include?('dude'))

    item.save
    item.reset
    assert(item.tags.include?('dude'))

    item.tags.remove('dude')
    item.tags.add('greek')
    item.save
    item.reset
    assert(item.tags.include?('greek'))
    assert(!item.tags.include?('dude'))

    item = DirectedEdge::Item.new(@database, 'customer1')
    item.tags.remove('greek')
    item.save
    item.reset
    
    assert(!item.tags.include?('greek'))
  end

  def test_properties
    item = DirectedEdge::Item.new(@database, 'customer1')

    assert_equal(0, item.properties.length)

    item['test_property_1'] = 'test_value'
    item.save

    assert_equal(1, item.properties.length)
    assert_equal('test_value', item['test_property_1'])

    item['test_property_2'] = 'test_value'

    assert_equal(2, item.properties.length)
    assert_equal('test_value', item['test_property_2'])

    item['test_property_1'] = 'test_value_updated'

    assert_equal(2, item.properties.length)
    assert_equal('test_value_updated', item['test_property_1'])

    # Test the cached example of clearing a property
    
    item.properties.remove('test_property_1')
    assert(!item.properties.include?('test_property_1'))

    # Make sure that it stays gone when reloading

    item.save
    item.reset
    assert(!item.properties.include?('test_property_1'))

    # Test the incremental update

    item['test_property_1'] = 'test_value'
    item.save

    item = DirectedEdge::Item.new(@database, 'customer1')
    item.properties.remove('test_property_1')
    item.save
    item.reset
    assert(!item.properties.include?('test_property_1'))
  end

  def test_link_types
    first = DirectedEdge::Item.new(@database, 'item_1')
    second = DirectedEdge::Item.new(@database, 'item_2')
    first.save
    second.save

    first.links.add(second, :type => :test)
    first.save

    first = DirectedEdge::Item.new(@database, 'item_1')
    second = DirectedEdge::Item.new(@database, 'item_2')

    first.save
    first.reset
    second.reset

    assert(first.links.include?(DirectedEdge::Link.new('item_2', :type => :test)))
    assert(!first.links.include?(DirectedEdge::Link.new('item_2')))
  end

  def test_load
    return if ENV['NO_LOAD_TEST']

    Process.setrlimit(Process::RLIMIT_NOFILE, 4096, 65536)

    def run_load_test(prefix, count)
      (1..count).concurrently do |i|
        item = DirectedEdge::Item.new(@database, "test_item_#{prefix}_#{i}")
        item.tags.add('test_tag')
        item.save
      end
      (1..count).concurrently do |i|
        item = DirectedEdge::Item.new(@database, "test_item_#{prefix}_#{i}")
        item['test_property'] = 'test_value'
        item.save
      end
      (1..count).concurrently do |i|
        item = DirectedEdge::Item.new(@database, "test_item_#{prefix}_#{i}")
        assert_equal(1, item.tags.length)
        assert_equal(1, item.properties.length)
      end
    end

    # Run 5 sets of load tests which each create 100 items, add a property to
    # them, and then query them to make sure the tag and properties on each of
    # them are correct

    (1..5).concurrently do |i|
      # Stagger the results so that reads and writes are interleaved
      sleep(i - 1)
      run_load_test(i, 100)
    end
  end

  def test_rankings
    customer1 = DirectedEdge::Item.new(@database, 'customer1')
    customer2 = DirectedEdge::Item.new(@database, 'customer2')
    customer3 = DirectedEdge::Item.new(@database, 'customer3')

    # Test an out of range ranking.

    customer1.links[customer2] = -1
    assert_raise(RestClient::UnprocessableEntity) { customer1.save }

    # And another.

    customer1.reload
    customer1.links[customer2] = 100
    assert_raise(RestClient::UnprocessableEntity) { customer1.save }

    customer1.reload
    customer1.link_to(customer3, 10)
    customer1.save
    customer1.reload
    assert_equal(10, customer1.weight_for(customer3))
  end

  def test_group_related
    assert_equal(0, @database.group_related([], ['product']).size)
    assert_equal(20, @database.group_related(['product1', 'product2'], ['product']).size)
  end

  def test_unsafe_chars
    item = DirectedEdge::Item.new(@database, ';@%&!')
    item['foo'] = 'bar'
    item.save

    item = DirectedEdge::Item.new(@database, ';@%&!')
    assert(item['foo'] == 'bar')

    item = DirectedEdge::Item.new(@database, 'foo/bar')
    item['foo'] = 'bar'
    item.save

    item = DirectedEdge::Item.new(@database, 'foo/bar')
    assert(item['foo'] == 'bar')
  end

  def test_bad_links
    item = DirectedEdge::Item.new(@database, 'does not exist')
    assert_raise(RestClient::ResourceNotFound) { item.destroy }

    item = DirectedEdge::Item.new(@database, 'customer1')
    item.link_to('also does not exist')
    assert_raise(RestClient::UnprocessableEntity) { item.save }
  end

  def test_query_parameters
    item = DirectedEdge::Item.new(@database, 'product1')
    assert_equal(5, item.related(['product'], :max_results => 5).size)

    item.link_to('product21')
    item.save

    assert(item.related(['product']).include?('product21'))
    assert(!item.related(['product'], :exclude_linked => true).include?('product21'))
  end

  def test_include_properties
    item = DirectedEdge::Item.new(@database, 'product1')
    other = DirectedEdge::Item.new(@database, 'product21')
    other['foo'] = 'bar'
    other.save
    related = item.related(['product'], :include_properties => true)
    assert_equal('bar', related['product21']['foo'])

    related = @database.group_related(['product1'], ['product'], :include_properties => true)
    assert_equal('bar', related['product21']['foo'])

    customer = DirectedEdge::Item.new(@database, 'customer2')
    recommended = customer.recommended(['product'], :include_properties => true)
    assert_equal('bar', recommended['product21']['foo'])
  end

  def test_include_tags
    item = DirectedEdge::Item.new(@database, 'product1')
    item.add_preselected('product2')
    item.save

    related = item.related(['product'], :include_tags => true)
    assert(related['product2']['tags'].is_a? Array)
    assert(related['product2']['tags'].include?('product'))

    target = DirectedEdge::Item.new(@database, 'product2')
    target.add_tag('foo')
    target.save

    related = item.related(['product'], :include_tags => true)
    assert(related['product2']['tags'].include?('product'))
    assert(related['product2']['tags'].include?('foo'))
  end

  def test_preselected
    item = DirectedEdge::Item.new(@database, 'product1')

    first = item.related[0]

    item.add_preselected('product2')
    item.add_preselected('product3')
    item.save
    item.reload
    assert_equal(2, item.preselected.length)
    assert_equal('product2', item.preselected[0])
    assert_equal('product3', item.preselected[1])

    related = item.related
    assert_equal('product2', item.related[0])
    assert_equal('product3', item.related[1])

    item.remove_preselected('product2')
    item.save
    item.reload
    assert_equal(1, item.preselected.length)

    item.remove_preselected('product3')
    item.save
    assert_equal(first, item.related[0])

    # Make sure that internal properties aren't overwriting normal properties

    item['foo'] = 'bar'
    item.save
    item.add_preselected('product2')
    item.save
    item.reload
    assert_equal(item['foo'], 'bar')
  end

  def test_blacklisted
    customer = DirectedEdge::Item.new(@database, 'customer1')
    first = customer.recommended(['product']).first
    customer.add_blacklisted(first)
    customer.save
    assert(!customer.recommended(['product']).include?(first))

    assert(customer.blacklisted.include?(first))
    customer.reload
    assert(customer.blacklisted.include?(first))

    customer.remove_blacklisted(first)
    customer.save
    assert(!customer.blacklisted.include?(first))
    customer.reload
    assert(!customer.blacklisted.include?(first))
    assert(customer.recommended(['product']).include?(first))
  end

  def test_timeout
    return unless ENV['TEST_TIMEOUT']
    timeout = 5
    database = DirectedEdge::Database.new('dummy', 'dummy', 'http',
                                          :host => 'localhost:4567', :timeout => timeout)
    start = Time.now
    timed_out = false

    begin
      item = DirectedEdge::Item.new(database, 'dummy')
      item.tags
    rescue RestClient::RequestTimeout
      timed_out = true
      assert(Time.now - start < timeout + 1)
    rescue
    end

    assert(timed_out)
  end
end
