<?php

require_once('PHPUnit/Framework.php');
require_once('DirectedEdge.php');

class QueryTest extends PHPUnit_Framework_TestCase
{
    private $database;
    private $customer;
    private $product;

    protected function setUp()
    {
        $this->database = new DirectedEdgeDatabase(getenv('DIRECTEDEDGE_TEST_DB'),
                                                   getenv('DIRECTEDEDGE_TEST_PASS'));
        $this->database->import('../testdb.xml');

        $this->customer = new DirectedEdgeItem($this->database, 'customer1');
        $this->product = new DirectedEdgeItem($this->database, 'product1');
    }

    public function testLinks()
    {
        $this->assertEquals(15, count($this->customer->getLinks()));
        $this->assertArrayHasKey('product4', $this->customer->getLinks());

        $customer3 = new DirectedEdgeItem($this->database, 'customer3');
        $this->customer->linkTo($customer3, 10);

        $this->assertArrayHasKey('customer3', $this->customer->getLinks());
        $this->assertEquals(10, $this->customer->getWeightFor('customer3'));
    }

    /** 
     * @expectedException OutOfRangeException
     */
    public function testWeightUpperRange()
    {
        $this->customer->linkTo($this->product, 11);
    }

    /** 
     * @expectedException OutOfRangeException
     */
    public function testWeightLowerRange()
    {
        $this->customer->linkTo($this->product, -1);
    }

    public function testTags()
    {
        $this->assertEquals(1, count($this->customer->getTags()));
        $this->customer->addTag('foo');
        $this->assertContains('foo', $this->customer->getTags());
    }

    public function testRelated()
    {
        $this->assertEquals(5, count($this->product->getRelated(array(), array(maxResults => 5))));
        $this->assertContains('product21', $this->product->getRelated(array('product')));
    }

    public function testGroupRelated()
    {
        $results = $this->database->getGroupRelated(array('product1', 'product2'), array('product'));
        $this->assertEquals(20, count($results));

        $results = $this->database->getGroupRelated(array($this->product), array('product'));
        $this->assertEquals(20, count($results));

        $results = $this->database->getGroupRelated(array($this->product, 'product2'), array('product'));
        $this->assertEquals(20, count($results));
    }

    public function testRecommended()
    {
        $this->assertNotContains('product21', $this->customer->getRecommended(array('product')));
    }

    public function testProperties()
    {
        $this->customer->setProperty('foo', 'bar');
        $this->assertEquals('bar', $this->customer->getProperty('foo'));
        $this->customer->setProperty('baz', 'quux');
        $this->assertEquals('quux', $this->customer->getProperty('baz'));
        $this->customer->clearProperty('baz');
        $this->assertArrayNotHasKey('baz', $this->customer->getProperties());
        $this->assertArrayNotHasKey('quux', $this->customer->getProperties());
    }

    public function testSave()
    {
        $foo = new DirectedEdgeItem($this->database, 'Foo');
        $foo->addTag('blah');
        $foo->save();

        $foo = new DirectedEdgeItem($this->database, 'Foo');
        $this->assertContains('blah', $foo->getTags());
        $foo = new DirectedEdgeItem($this->database, 'Foo');
        $foo->removeTag('blah');
        $foo->save();
        $foo = new DirectedEdgeItem($this->database, 'Foo');
        $this->assertNotContains('blah', $foo->getTags());

        $foo = new DirectedEdgeItem($this->database, 'Foo');
        $foo->setProperty('baz', 'quux');
        $foo->save();
        $foo = new DirectedEdgeItem($this->database, 'Foo');
        $this->assertEquals('quux', $foo->getProperty('baz'));
        $foo = new DirectedEdgeItem($this->database, 'Foo');
        $foo->setProperty('baz', 'bar');
        $foo->save();
        $foo = new DirectedEdgeItem($this->database, 'Foo');
        $this->assertEquals('bar', $foo->getProperty('baz'));
        $foo->clearProperty('baz');
        $foo->save();
        $foo = new DirectedEdgeItem($this->database, 'Foo');
        $this->assertArrayNotHasKey('baz', $foo->getProperties());

        $bar = new DirectedEdgeItem($this->database, 'Bar');
        $bar->linkTo($foo, 10);
        $bar->save();
        $bar = new DirectedEdgeItem($this->database, 'Bar');
        $links = $bar->getLinks();
        $this->assertEquals(10, $links['Foo']);
        $bar->unlinkFrom($foo);
        $bar->save();
        $bar = new DirectedEdgeItem($this->database, 'Bar');
        $this->assertArrayNotHasKey('Foo', $bar->getLinks());
    }

    public function testExport()
    {
        $exporter = new DirectedEdgeExporter('exported.xml');

        $foo = new DirectedEdgeItem($exporter->getDatabase(), 'Foo');
        $foo->addTag('blah');
        $foo->setProperty('baz', 'quux');
        $exporter->export($foo);

        $bar = new DirectedEdgeItem($exporter->getDatabase(), 'Bar');
        $bar->linkTo($foo, 5, 'magic');
        $exporter->export($bar);

        $exporter->finish();
    }

    public function testAdd()
    {
        $item = new DirectedEdgeItem($this->database, 'Asdf');
        $this->assertEquals(0, count($item->getTags()));
    }

    public function testLinkTypes()
    {
        $foo = new DirectedEdgeItem($this->database, 'Foo');
        $bar = new DirectedEdgeItem($this->database, 'Bar');

        $foo->linkTo($bar, 0, 'thinger');

        $bar->save();
        $foo->save();

        $foo = new DirectedEdgeItem($this->database, 'Foo');
        $bar = new DirectedEdgeItem($this->database, 'Bar');

        $this->assertContains('thinger', $foo->getLinkTypes());
    }

    public function testDatabaseRelated()
    {
        $items = array('product1', 'product2', 'product3');
        $tags = array('product');
        $related = $this->database->getRelated(
            $items, $tags, array(threshold => 0.5 /* , countOnly => 'true' */));

        $results = $this->database->getRelated(array('product1', 'product2'), array('product'));
        $this->assertEquals(2, count($results));
        $this->assertEquals(20, count($results['product1']));
        $this->assertEquals(20, count($results['product2']));
        $this->assertEquals($this->product->getRelated(array('product')), $results['product1']);
    }
}

?>