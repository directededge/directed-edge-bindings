require File.expand_path(File.dirname(__FILE__) + '/helper')

# Defines a multithreaded "each"

module Enumerable
  def concurrently
    map { |item| Thread.new { yield item } }.each { |t| t.join }
  end
end

class TestDirectedEdge < Test::Unit::TestCase
  TESTDB_FILE = File.expand_path('../../../testdb.xml', __FILE__)

  def setup
    @user = ENV['DIRECTEDEDGE_TEST_DB']
    @pass = ENV['DIRECTEDEDGE_TEST_PASS']
    @database = DirectedEdge::Database.new(@user, @pass)
    @database.import(TESTDB_FILE)
  end

  def test_updatejob
    DirectedEdge::UpdateJob.run(@database, :update) do |job|
      job.item('test_1') { |i| i.tags.add 'test' }
    end

    assert(item('test_1').tags.include?('test'))

    DirectedEdge::UpdateJob.run(@user, @pass, :update) do |job|
      job.item('test_2') { |i| i.tags.add 'test' }
    end

    assert(item('test_2').tags.include?('test'))

    DirectedEdge::UpdateJob.run(@database, :update) do |job|
      job.item('test_1') { |i| i.tags.add 'test' }
    end

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

    user = item('test_user_1')
    product = item('test_product')

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

    item = item('Foo')
    assert_equal('Bar', item['name'])
  end

  def test_update_job_destroy
    DirectedEdge::UpdateJob.run(@database, :update) do |job|
      job.item('product1') { |i| i.destroy }
      job.item('product2').destroy
      job.destroy(DirectedEdge::Item.new(@database, 'product3'))
    end
    assert(!DirectedEdge::Item.new(@database, 'product1').exists?)
    assert(!DirectedEdge::Item.new(@database, 'product2').exists?)
    assert(!DirectedEdge::Item.new(@database, 'product3').exists?)
  end

  def test_items
    first_item = item('test_1')
    first_item.save

    second_item = item('test_2')
    second_item.links.add(first_item)
    second_item.save

    third_item = item('test_3')
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

    assert(third_item.related.include?(first_item))
    assert(third_item.related.include?(second_item))

    # Since linked items are excluded from recommendations, nothing should show
    # up in the recommended items for the third item.

    assert_equal(0, third_item.recommended.length)
    assert_equal(1, second_item.recommended.length)
    assert_equal(0, second_item.recommended(:tags => 'unknown_tag').length)
    assert_equal(third_item.to_s, first_item.recommended(:tags => 'test_tag').first.to_s)

    # Test fallback algorithm override

    product = item('product1')
    assert(!product.recommended.empty?)
    assert(product.recommended(:disable_fallback_to_related => true).empty?)

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

    first_item.reset
    assert_equal(0, first_item.links.length)
  end

  def test_tags
    item = item('customer1')
    item.tags.add('dude')
    item.tags.add([ 'wheres', 'my', 'car' ])
    assert(item.tags.include?('dude'))
    assert(item.tags.include?('wheres'))
    assert(item.tags.include?('my'))
    assert(item.tags.include?('car'))

    item.save
    assert(item.tags.include?('dude'))

    item.tags.remove('dude')
    item.tags.add('greek')
    item.save
    assert(item.tags.include?('greek'))
    assert(!item.tags.include?('dude'))

    item = item('customer1')
    item.tags.remove('greek')
    item.save

    assert_raise(TypeError, RuntimeError) { item.tags.push('mutable') }

    assert(!item.tags.include?('greek'))
  end

  def test_properties
    item = item('customer1')

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
    assert(!item.properties.include?('test_property_1'))

    # Test the incremental update

    item['test_property_1'] = 'test_value'
    item.save

    item = item('customer1')
    item.properties.remove('test_property_1')
    item.save
    assert(!item.properties.include?('test_property_1'))
  end

  def test_link_types
    first = item('item_1')
    second = item('item_2')
    first.save
    second.save

    first.links.add(second, :type => :test)
    first.save

    first = item('item_1')
    second = item('item_2')

    first.save

    assert(first.links.include?(DirectedEdge::Link.new('item_2', :type => :test)))
    assert(!first.links.include?(DirectedEdge::Link.new('item_2')))
  end

  def test_load
    return unless ENV['DIRECTEDEDGE_LOAD_TEST']

    begin
      Process.setrlimit(Process::RLIMIT_NOFILE, 4096, 65536)
    rescue
      # It's ok if the above fails.
    end

    def run_load_test(prefix, count)
      (1..count).concurrently do |i|
        item = item("test_item_#{prefix}_#{i}")
        item.tags.add('test_tag')
        item.save
      end
      (1..count).concurrently do |i|
        item = item("test_item_#{prefix}_#{i}")
        item['test_property'] = 'test_value'
        item.save
      end
      (1..count).concurrently do |i|
        item = item("test_item_#{prefix}_#{i}")
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

  def test_weights
    customer1 = item('customer1')
    customer2 = item('customer2')
    customer3 = item('customer3')

    # Test an out of range ranking.

    customer1.links.add(customer2, :weight => -1)
    assert_raise(RestClient::UnprocessableEntity) { customer1.save }

    # And another.

    customer1.reset
    customer1.links.add(customer2, :weight => 100)
    assert_raise(RestClient::UnprocessableEntity) { customer1.save }

    customer1.reset
    customer1.links.add(customer3, :weight => 10)
    customer1.save
    assert_equal(10, customer1.links[customer3].weight)
  end

  def test_items_to_rank
    product = item('product1')
    targets = (2..10).map { |i| "product#{i}" }

    results = product.related(:items_to_rank => targets)
    assert_operator(results.size, :<=, targets.size)

    results = product.related(:items_to_rank => targets, :include_unranked => true)
    assert_equal(targets.size, results.size)
  end

  def test_multiple_items
    # @database.items('customer1').first.properties['foo'] = 'bar'
    item('customer1')['foo'] = 'bar'


    assert(@database.items('customer1').is_a?(Array))
    assert_equal(1, @database.items('customer1').length)
    assert(@database.items('customer1').first.tags == [ 'customer' ])

    assert(@database.items([ 'customer1' ]).is_a?(Array))
    assert_equal(1, @database.items([ 'customer1' ]).length)

    assert(@database.items([ 'customer1', 'customer2' ]).is_a?(Array))
    assert_equal(2, @database.items([ 'customer1', 'customer2' ]).length)

    assert(@database.items([ 'customer1', 'does_not_exist' ]).is_a?(Array))
    assert_equal(1, @database.items([ 'customer1', 'does_not_exist' ]).length)

    assert(@database.items('does_not_exist').is_a?(Array))
    assert(@database.items('does_not_exist').empty?)
  end

  def test_group_related
    assert_equal(0, @database.related([], :tags => 'product').size)
    assert_equal(20, @database.related([ 'product1', 'product2' ], :tags => 'product').size)
  end

  def test_unsafe_chars
    return unless @database.resource.head.headers[:server].include?('nginx')

    item = item(';@%&!')
    item['foo'] = 'bar'
    item.save

    item = item(';@%&!')
    assert(item['foo'] == 'bar')

    item = item('foo/bar')
    item['foo'] = 'bar'
    item.save

    item = item('foo/bar')
    assert(item['foo'] == 'bar')

    item = item('bad')
    item['bad'] = "bad\u{1a}"
    item.save
    item.reset
    assert(item['bad'] == 'bad')

    item.tags.add("bad\u{1a}")
    item.save
    item.reset
    assert(item.tags.include?('bad'))
end

  def test_bad_links
    item = item('does not exist')
    assert_raise(RestClient::ResourceNotFound) { item.destroy }

    item = item('customer1')
    item.links.add('also does not exist')
    assert_raise(RestClient::UnprocessableEntity) { item.save }
  end

  def test_query_parameters
    item = item('product1')
    assert_equal(5, item.related(:tags => 'product', :max_results => 5).size)

    item.links.add('product21')
    item.save

    assert(item.related(:tags => 'product').include?(item('product21')))
    assert(!item.related(:tags => 'product', :exclude_linked => true).include?('product21'))
  end

  def test_include_properties
    item = item('product1')
    other = item('product21')
    other['foo'] = 'bar'
    other.save
    related = item.related(:tags => 'product', :include_properties => true)
    assert_equal('bar', related['product21'].properties['foo'])

    related = @database.related('product1', :tags => 'product', :include_properties => true)
    assert_equal('bar', related['product21'].properties['foo'])

    customer = item('customer2')
    recommended = customer.recommended(:tags => 'product', :include_properties => true)
    assert_equal('bar', recommended['product21'].properties['foo'])
  end

  def test_include_tags
    item = item('product1')
    item.preselected.add('product2')
    item.save

    related = item.related(:tags => 'product', :include_tags => true)
    assert(related['product2'].properties['tags'].include?('product'))

    target = item('product2')
    target.tags.add('foo')
    target.save

    item.reset
    related = item.related(:tags => 'product', :include_tags => true)

    assert(related['product2'].properties['tags'].split(',').include?('product'))
    assert(related['product2'].properties['tags'].split(',').include?('foo'))
  end

  def test_preselected
    item = item('product1')

    first = item.related[0]

    item.preselected.add('product2')
    item.preselected.add('product3')
    item.save

    assert_equal(2, item.preselected.length)
    assert_equal(item('product2'), item.preselected[0])
    assert_equal(item('product3'), item.preselected[1])

    related = item.related
    assert_equal(item('product2'), item.related[0])
    assert_equal(item('product3'), item.related[1])

    item.preselected.remove('product2')
    item.save
    assert_equal(1, item.preselected.length)

    item.preselected.remove('product3')
    item.save
    assert_equal(first, item.related[0])

    # Make sure that internal properties aren't overwriting normal properties

    item['foo'] = 'bar'
    item.save
    item.preselected.add('product2')
    item.save
    assert_equal(item['foo'], 'bar')
  end

  def test_ignore_preselected
    dummy = item('dummy')
    dummy.save

    item = item('product1')
    item.preselected.add(dummy)
    item.save

    assert_equal(item.related.first, dummy)
    assert_not_equal(item.related(:ignore_preselected => true).first, dummy)
  end

  def test_only_preselected
    dummy = item('dummy')
    dummy.save

    item = item('product1')
    item.preselected.add(dummy)
    item.save

    assert_equal(item.related.first, dummy)
    assert_equal(item.related(:only_preselected => true).first, dummy)
    assert_equal(item.related(:only_preselected => true).length, 1)
  end

  def test_blacklisted
    customer = item('customer1')
    first = customer.recommended(:tags => 'product').first
    customer.blacklisted.add(first)
    customer.save
    assert(!customer.recommended(:tags => 'product').include?(first))

    assert(customer.blacklisted.include?(first))

    customer.blacklisted.remove(first)
    customer.save
    assert(!customer.blacklisted.include?(first))
    assert(customer.recommended(:tags => 'product').include?(first))
  end

  def test_exists
    item = item('does_not_exist')
    assert(!item.exists?)
    assert(item.links.empty?)

    item = item('customer1')
    assert(item.exists?)
    assert(!item.links.empty?)
  end

  def test_histories
    assert(@database.histories.empty?)

    history = DirectedEdge::History.new(:from => :customer, :to => :product)

    @database.histories.add(history)

    assert(@database.histories.size == 1)
    assert(@database.histories.first == history)

    dummy = DirectedEdge::History.new(:from => :foo, :to => :bar)

    @database.histories.add(dummy)

    assert(@database.histories.size == 2)
    assert(@database.histories.include?(history))
    assert(@database.histories.include?(dummy))

    @database.histories.remove(dummy)

    assert(@database.histories.size == 1)
    assert(@database.histories.first == history)

    @database.histories = []

    assert(@database.histories.empty?)

    @database.histories = [ history, dummy ]

    assert(@database.histories.size == 2)
    assert(@database.histories.include?(history))
    assert(@database.histories.include?(dummy))
  end

  def test_history_entries
    history = DirectedEdge::History.new(:from => :customer, :to => :product)
    @database.histories = [ history ]

    customer = item('customer1')
    product = item('product1')

    assert(customer.history_entries.empty?)

    customer.history_entries.add(DirectedEdge::HistoryEntry.new(history, product))
    customer.save

    assert(customer.history_entries.size == 1)
  end

  def test_gzipped_import
    count = item_count
    @database.clear!
    assert_equal(item_count, 0)
    @database.import("#{TESTDB_FILE}.gz")
    assert_equal(item_count, count)
  end

  private

  def item(id)
    DirectedEdge::Item.new(@database, id)
  end

  def item_count
    Oga.parse_xml(@database.resource[:statistics].get).at_xpath('//items').inner_text.to_i
  end
end
