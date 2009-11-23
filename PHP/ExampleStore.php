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

?>