<?php

/*
 * Copyright (C) 2009 Directed Edge, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

require_once('DirectedEdge.php');

/*
 * Ok, so the basics of how this thing works:
 *
 * It assumes that you have a local database for your store, and that store
 * has a "customer" table and "products" table.  In each of those tables
 * you have a unique ID that corresponds to each customer and product,
 * respectively.
 *
 * It also assumes there's a third table, named "purchases" that has a list of
 * things purchased by customers.  Basically a mapping from the customer ID to
 * the product ID.  All of this is pretty standard store stuff.
 *
 * So, then what this class does is it handles:
 *
 * - Getting that data from those tables over to Directed Edge
 * - Doing incremental updates (adding customers, products, purchases)
 * - Finding products related to a given product
 * - Finding personalized product recommendations for a customer
 *
 * This is really just the starting point; there are some other exciting things
 * that can be done with the API once you've gotten your feet wet.
 */

define('DB_HOST', 'localhost');
define('DB_USER', 'examplestore');
define('DB_PASS', 'password');
define('DB_NAME', 'examplestore');

define('DIRECTEDEDGE_USER', 'examplestore');
define('DIRECTEDEDGE_PASS', 'password');

define('EXPORT_FILE', 'examplestore.xml');

class ExampleStore
{
    private $database;

    public function __construct()
    {

        mysql_connect(DB_HOST, DB_USER, DB_PASS);

        if(!mysql_select_db(DB_NAME))
        {
            throw new Exception("Could not connect to DB.");
        }

        $this->database = new DirectedEdgeDatabase(DIRECTEDEDGE_USER, DIRECTEDEDGE_PASS);
    }

    /**
     * Export the list of products, purchases and customers to an XML file that
     * we can later push to the Directed Edge webservices.
     */

    public function exportFromMySQL()
    {
        $exporter = new DirectedEdgeExporter(EXPORT_FILE);

        foreach($this->getProducts() as $product)
        {
            $item = new DirectedEdgeItem($exporter->getDatabase(), 'product' . $product);
            $item->addTag('product');
            $exporter->export($item);
        }

        foreach($this->getCustomers() as $customer)
        {
            $item = new DirectedEdgeItem($exporter->getDatabase(), 'customer' . $customer);

            foreach($this->getPurchasesForCustomer($customer) as $product)
            {
                $item->linkTo('product' . $product);
            }

            $exporter->export($item);
        }

        $exporter->finish();
    }

    /**
     * Import the file that we created using exportFromMySQL to the Directed Edge
     * webservices.
     */

    public function importToDirectedEdge()
    {
        $this->database->import(EXPORT_FILE);
    }

    /**
     * Create a customer in the Directed Edge database that corresponds to the
     * customer in the local database with $id.
     */

    public function createCustomer($id)
    {
        $item = new DirectedEdgeItem($this->database, 'customer' . $id);
        $item->addTag('customer');
        $item->save();
    }

    /**
     * Create a product in the Directed Edge database that corresponds to the
     * product in the local database with $id.
     */

    public function createProduct($id)
    {
        $item = new DirectedEdgeItem($this->database, 'product' . $id);
        $item->addTag('product');
        $item->save();
    }

    /**
     * Create a purchase in the Directed Edge database from the product with
     * the local database IDs $customerId and $productId.
     */

    public function addPurchase($customerId, $productId)
    {
        $item = new DirectedEdgeItem($this->database, 'customer' . $customerId);
        $item->linkTo('product' . $productId);
        $item->save();
    }

    /**
     * Returns a list of related product IDs for the product ID that's passed in.
     */

    public function getRelatedProducts($productId)
    {
        $item = new DirectedEdgeItem($this->database, 'product' . $productId);
        $related = array();

        foreach($item->getRelated(array('product')) as $item)
        {
            $related[] = str_replace('product', '', $item);
        }

        return $related;
    }

    /**
     * Returns a list of recommended products for the customer ID that's passed in.
     */

    public function getPersonalizedRecommendations($customerId)
    {
        $item = new DirectedEdgeItem($this->database, 'customer' . $customerId);
        $recommended = array();

        foreach($item->getRecommended(array('product')) as $item)
        {
            $recommended[] = str_replace('product', '', $item);
        }

        return $recommended;
    }

    private function getCustomers()
    {
        $result = mysql_query("select id from customers");
        $customers = array();

        while($row = mysql_fetch_row($result))
        {
            $customers[] = $row[0];
        }

        return $customers;
    }

    private function getProducts()
    {
        $result = mysql_query("select id from products");
        $products = array();

        while($row = mysql_fetch_row($result))
        {
            $products[] = $row[0];
        }

        return $products;
    }

    private function getPurchasesForCustomer($customer)
    {
        $result = mysql_query(sprintf("select product from purchases where customer = '%s'",
                                      mysql_real_escape_string($customer)));
        $purchases = array();

        while($row = mysql_fetch_row($result))
        {
            $purchases[] = $row[0];
        }

        return $purchases;
    }
}

$store = new ExampleStore();
$store->exportFromMySQL();
$store->importToDirectedEdge();

$store->createCustomer(1000);
$store->createProduct(1000);
$store->addPurchase(1000, 1000);

print_r($store->getRelatedProducts(2));
print_r($store->getPersonalizedRecommendations(2));

?>