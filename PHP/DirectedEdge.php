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

require_once('HTTP/Request2.php');

function array_remove($haystack, $needle)
{
    $result = array();

    foreach($haystack as $value)
    {
        if($value != $needle)
        {
            $result[] = $value;
        }
    }

    return $result;
}

function array_insert($haystack, $needle)
{
    if(!in_array($needle, $haystack))
    {
        $haystack[] = $needle;
    }

    return $haystack;
}

/**
 * Simple exception class that is used when there is a problem communicating
 * with the Directed Edge web services or if an item can not be found.
 */

class DirectedEdgeException extends Exception
{
    private $httpCode;

    /**
     * @param integer HTTP status code
     * @param string HTTP text message
     */
    public function __construct($code, $reason)
    {
        $this->httpCode = $code;

        if($code == 404)
        {
            parent::__construct("Could not find item.");
        }
        else
        {
            parent::__construct($reason);
        }
    }

    /**
     * @return The HTTP error code.
     */
    public function getHttpCode()
    {
        return $this->httpCode;
    }
}

/**
 * Simple conceptualization of a REST resource, with support for GET, PUT and
 * DELETE HTTP methods.
 */

class DirectedEdgeResource
{
    private $base;

    /**
     * Constructs a resource.
     * @param string The base URL from which further resources are considered
     * sub-resources.
     */

    public function __construct($base)
    {
        $this->base = $base;
    }
    
    /**
     * Indexes into a sub-resource.
     *
     * @param string Just the sub-resource itself's name (e.g. 'related')
     * @return string The full path to a subresource.
     */

    public function path($path = '')
    {
        return $this->base . '/' . urlencode($path);
    }

    /**
     * Performs an HTTP GET on the resource and returns the contents.
     *
     * @param string A sub-resource to fetch.
     * @return string The contents of the resource.
     * @throws DirectedEdgeException Thrown if there is a connection problem or the resource
     * could not be found.
     */

    public function get($path = '', $params = array())
    {
        $request = new HTTP_Request2($this->path() . $path);
        $request->getUrl()->setQueryVariables($params);

        $response = $request->send();

        if($response->getStatus() != 200)
        {
            throw new DirectedEdgeException($response->getStatus(),
                                            $response->getReasonPhrase());
        }

        return $response->getBody();
    }

    /**
     * Performs an HTTP PUT on the resource.
     *
     * @param string The data to upload to the (sub-) resource. May be a file
     * name or the content itself.
     * @param string The sub-resource to upload to.
     * @throws DirectedEdgeException Thrown if there is a connection problem or the resource
     * could not be found.
     */

    public function put($content, $path = '')
    {
        $request = new HTTP_Request2($this->path() . $path, HTTP_Request2::METHOD_PUT);
        $request->setBody($content, file_exists($content));
        $response = $request->send();

        if($response->getStatus() != 200)
        {
            throw new DirectedEdgeException($response->getStatus(),
                                            $response->getReasonPhrase());
        }
    }

    /**
     * Performs an HTTP DELETE on the resource.
     *
     * @param string The sub-resource to be deleted.
     * @throws DirectedEdgeException Thrown if there is a connection problem or the resource
     * could not be found.
     */

    public function delete($path = '')
    {
        $request = new HTTP_Request2($this->path() . $path, HTTP_Request2::METHOD_DELETE);
        $response = $request->send();

        if($response->getStatus() != 200)
        {
            throw new DirectedEdgeException($response->getStatus(),
                                            $response->getReasonPhrase());
        }
    }

    public function __toString()
    {
        return $this->base;
    }
}

/**
 * A Database is an encapsulation of a database being accessed via the Directed
 * Edge web-services API.  You can request database creation by visiting
 * http://www.directededge.com/ and will recieve a user name and password which
 * are then used to connect to your DirectedEdgeDatabase instance.
 *
 * Usually when getting started with a DirectedEdge database, users would like to
 * import some pre-existing data, usually from their web application's database.
 * The Database class has an import method which can be used to import data using
 * Directed Edge's XML format.  Files formatted in that way may be created with
 * the Exporter.
 *
 * A database is typically instantiated via:
 *
 * <code>
 * $database = new DirectedEdgeDatabase('mydatabase', 'mypassword');
 * </code>
 */

class DirectedEdgeDatabase
{
    private $resource;

    /**
     * Creates a connection to a Directed Edge database.
     *
     * @param string The account / database name for the database.
     * @param string The password for the account.
     * @param string The protocol to be used -- http or https.
     */

    public function __construct($name, $password = '', $protocol = 'http')
    {
        $host = $_ENV['DIRECTEDEDGE_HOST'];

        if(!$host)
        {
            $host = 'webservices.directededge.com';
        }

        $base = "$protocol://$name:$password@$host/api/v1/$name";

        $this->resource = new DirectedEdgeResource($base);
    }

    /**
     * @return DirectedEdgeResource The REST resource used for connecting to the database.
     */

    public function resource()
    {
        return $this->resource;
    }

    /**
     * Imports a Directed Edge XML file to the database.
     *
     * See http://developer.directededge.com/ for more information on the XML format or the
     * Exporter for help on creating a file for importing.
     *
     * @param string File name with the contents to be imported.
     */

    public function import($fileName)
    {
        $this->resource->put($fileName);
    }

    /**
     * Returns multiple sets of related items for the database based on the IDs in items.
     *
     * @param Array Matches must have at least one of the tags specified.
     * @param Array An array of link types and link weights.
     * @return Array A list of related items sorted by relevance.
     */
    public function getRelated($items, $tags = array(), $options = array(), $linkWeights = array())
    {
        if(count($items) <= 0)
        {
            return array();
        }

        $options = DirectedEdgeItem::mergeOptions($tags, $options, $linkWeights);
        $options[items] = implode(",", $items);
        $content = $this->resource->get('related', $options);
        $document = new DOMDocument();
        $document->loadXML($content);

        $itemElements = $document->getElementsByTagName('item');
        $results = array();

        for($i = 0; $i < $itemElements->length; $i++)
        {
            $id = $itemElements->item($i)->attributes->getNamedItem('id')->value;

            if($options[countOnly] == "true")
            {
                $count = DirectedEdgeItem::getValuesByTagName($itemElements->item($i), 'count');
                $results[$id] = $count[0];
            }
            else
            {
                $results[$id] = DirectedEdgeItem::getValuesByTagName(
                    $itemElements->item($i), 'related');
            }
        }

        return $results;
    }
}

/**
 * Represents an item in a Directed Edge database.  Items can be products, pages
 * or users, for instance.  Usually items groups are differentiated from one
 * another by a set of tags that are provided.
 *
 * For instance, a user in the Directed Edge database could be modeled as:
 *
 * <code>
 * $user = new DirectedEdgeItem(database, 'user_1');
 * $user->addTag('user');
 * $user->save();
 * </code>
 *
 * Similarly a product could be:
 *
 * $product = new DirectedEdgeItem($database, 'product_1');
 * $product->addTag('product');
 * $product->setProperty('price', '$42');
 * $product->save();
 *
 * Note here that items have tags and properties.  Tags are a free-form set of
 * text identifiers that can be associated with an item, e.g. "user", "product",
 * "page", "science fiction", etc.
 *
 * Properties are a set of key-value pairs associated with the item.  For example,
 * <tt>$product->setProperty('price', '$42')</tt>, or
 * <tt>$product->setProperty('first name', 'Bob')</tt>.
 *
 * If we wanted to link the user to the product, for instance, indicating that the
 * user had purchased the product we can use:
 *
 * <code>
 * $user->linkTo($product);
 * $user->save();
 * </code>
 */

class DirectedEdgeItem
{
    private $database;
    private $id;
    private $resource;

    private $links = array();
    private $tags = array();
    private $properties = array();

    private $linksToRemove = array();
    private $tagsToRemove = array();
    private $propertiesToRemove = array();

    private $isCached = false;

    /**
     * Creates a handle to an item in the DirectedEdgeDatabase.  Changes made to
     * this item will not be reflected in the database until save() is called.
     *
     * @param DirectedEdgeDatabase The database that this item is (or will be) a part of.
     * @param string The unique identifier for the item (e.g. 'product12345')
     */

    public function __construct($database, $id)
    {
        $this->database = $database;
        $this->resource = new DirectedEdgeResource($database->resource()->path($id));
        $this->id = $id;
    }

    /**
     * @return string The unique identifier passed into the constructor when the
     * item was created.
     */

    public function getId()
    {
        return $this->id;
    }

    /**
     * @return Array An array with a mapping from link names (unique identifiers
     * of other items) to their weights.  An unweighted link will have zero as its
     * weight.
     *
     * For example:
     *
     * <tt>
     * Array
     * (
     *     [product1] => 0
     *     [product2] => 0
     * )
     * </tt>
     *
     * An item may have multiple link types, e.g. "purchase" or "rating" in
     * to the default type.  If no type argument is given the list of non-typed
     * links will be returned; if it is given the links of that type will be
     * returned.
     *
     * @see getLinkTypes()
     */

    public function getLinks($type = '')
    {
        $this->read();

        if($this->links[$type] == null)
        {
            return array();
        }

        return $this->links[$type];
    }

    /**
     * Link types are used to encode different sorts of relationships in the
     * Directed Edge engine.  For example, types might include:
     *
     * - Purchases
     * - Ratings
     * - Viewed Items
     * - Favorited
     *
     * And so on.  These link types may be encoded in into the Directed Edge
     * system and later used to influence related / recommended queries.
     *
     * @return Array A list of all link types in use by this item.
     */

    public function getLinkTypes()
    {
        $this->read();
        return array_keys($this->links);
    }

    /**
     * @return Array Simple list of all tags associated with this item.
     */

    public function getTags()
    {
        $this->read();
        return $this->tags;
    }

    /**
     * @return Array Key-value map for each property.
     */

    public function getProperties()
    {
        $this->read();
        return $this->properties;
    }

    /**
     * Gets the value of one of the item's properties.
     *
     * @param string The name of the property to fetch.
     * @return string The value of the given property.
     */

    public function getProperty($name)
    {
        $this->read();
        return $this->properties[$name];
    }

    /**
     * Creates or overwrites an existing property of the item.
     *
     * @param string Name of the property to set.
     * @param string Value to set.
     *
     * @note Changes will not be reflected in the database until save() is
     * called.
     */

    public function setProperty($name, $value)
    {
        unset($this->propertiesToRemove[$name]);
        $this->properties[$name] = $value;
    }

    /**
     * Removes a property from the item.
     *
     * @param string The name of the property be cleared from this items
     * properties.
     *
     * @note Changes will not be reflected in the database until save() is
     * called.
     */

    public function clearProperty($name)
    {
        $this->propertiesToRemove[$name] = '';
        unset($this->properties[$name]);
    }

    /**
     * Creates a link from this item to another item.
     *
     * @param string The ID of the item to link to.
     * @param integer The weight to be used, from 1 to 10 or 0 for an unweighted
     * link.
     * @param string An optional link type, e.g. "purchase" or "rating".
     *
     * @note Changes will not be reflected in the database until save() is
     * called.
     *
     * @warning $other must exist in the database or must have save() called on
     * it before it is called on this item or the link will be ignored.  This
     * is because the engine tries to detect (and discard) \em broken links that
     * do not terminate at a valid node.
     */

    public function linkTo($other, $weight = 0, $type = '')
    {
        ### Throw an error if this is out of range.

        if(!is_string($other))
        {
            $other = $other->getId();
        }

        unset($this->linksToRemove[$type][$other]);
        $this->links[$type][$other] = $weight;
    }

    /**
     * Unlinks the item from another item.
     *
     * @param string The unique ID of another item.
     * @param string The link type to be removed.
     * @param string Link type to be removed.
     *
     * @note Changes will not be reflected in the database until save() is
     * called.
     */

    public function unlinkFrom($other, $type = '')
    {
        if(!is_string($other))
        {
            $other = $other->getId();
        }

        $this->linksToRemove[$type][$other] = 0;
        unset($this->links[$type][$other]);
    }

    /**
     * @param string The unique ID of an item that this item is linked to.
     * @param string The link type to get the weight for.
     * @return integer The weight of the link from this item to @a other.
     */

    public function getWeightFor($other, $type = '')
    {
        $this->read();
        return $this->links[$type][$other];
    }

    /**
     * Adds a tag to the item.
     *
     * @param string The name of the tag to be added.
     *
     * @note Changes will not be reflected in the database until save() is
     * called.
     */

    public function addTag($tag)
    {
        $this->tagsToRemove = array_remove($this->tagsToRemove, $tag);
        $this->tags = array_insert($this->tags, $tag);
    }

    /**
     * Removes a tag from the item.
     *
     * @param string The name of the tag to be removed.
     *
     * @note Changes will not be reflected in the database until save() is
     * called.
     */

    public function removeTag($tag)
    {
        if(!$this->isCached)
        {
            $this->tagsToRemove = array_insert($this->tagsToRemove, $tag);
        }

        $this->tags = array_remove($this->tags, $tag);
    }

    /**
     * Writes all pending changes back to the database.
     */

    public function save()
    {
        if($this->isCached)
        {
            $this->resource->put($this->toXML());
        }
        else
        {
            $this->resource->put($this->toXML(), 'add');

            if(!empty($this->linksToRemove) ||
               !empty($this->tagsToRemove) ||
               !empty($this->propertiesToRemove))
            {
                $this->resource->put($this->toXML($this->linksToRemove,
                                                  $this->tagsToRemove,
                                                  $this->propertiesToRemove),
                                     'remove');
            }
        }
    }

    /**
     * Re-reads all links, tags and properties from the database and overwrites
     * any local changes.
     */

    public function reload()
    {
        $this->links = array();
        $this->tags = array();
        $this->properties = array();

        $this->linksToRemove = array();
        $this->tagsToRemove = array();
        $this->propertiesToRemove = array();

        $this->isCached = false;
        $this->read();
    }

    /**
     * Removes the item from the Directed Edge Database.  Acts immediately.
     */

    public function destroy()
    {
        $this->resource->delete();
    }

    /**
     * Finds related products, users, etc.  Note that there is a difference between
     * "related" and "recommended" methods -- related is used for similar products,
     * recommended for personalized recommendations.
     *
     * These related items may include items that this one is already linked to.
     *
     * @param Array Matches must have at least one of the tags specified.
     * @param Array An array of link types and link weights.
     * @return Array A list of related items sorted by relevance.
     */

    public function getRelated($tags = array(), $options = array(), $linkWeights = array())
    {
        return $this->query('related', $tags, $options, $linkWeights);
    }

    /**
     * Finds recommended products, users, etc.  Note that there is a difference between
     * "related" and "recommended" methods -- related is used for similar products,
     * recommended for personalized recommendations.
     *
     * This will not show any items that this item is already linked to.
     *
     * @param Array Matches must have at least one of the tags specified.
     * @return A list of recommended items sorted by relevance.
     */

    public function getRecommended($tags = array(), $options = array(), $linkWeights = array())
    {
        return $this->query('recommended', $tags, $options, $linkWeights);
    }

    /**
     * @return An XML representation of the item.
     *
     * @param Array Links to be included, defaults to this item's links.
     * @param Array Tags to be included, defaults to this item's tags.
     * @param Array Properties to be included, defaults to this item's properties.
     * @param bool Specifies if the full document should be returned or just item element
     * that's creates.
     * @return string XML representation of the item.
     *
     * @internal
     */

    public function toXML($links = null, $tags = null, $properties = null, $includeBody = true)
    {
        $links || $links = $this->links;
        $tags || $tags = $this->tags;
        $properties || $properties = $this->properties;

        $document = new DOMDocument();

        $directededge = $document->createElement('directededge');
        $directededge->setAttribute('version', 0.1);
        $document->appendChild($directededge);

        $item = $document->createElement('item');
        $item->setAttribute('id', $this->id);
        $directededge->appendChild($item);

        foreach($links as $type => $values)
        {
            foreach($values as $name => $weight)
            {
                $element = $document->createElement('link', $name);

                if(strlen($type) > 0)
                {
                    $element->setAttribute('type', $type);
                }

                if($values[$name] > 0)
                {
                    $element->setAttribute('weight', $weight);
                }

                $item->appendChild($element);
            }
        }

        foreach($tags as $tag)
        {
            $element = $document->createElement('tag', $tag);
            $item->appendChild($element);
        }

        foreach($properties as $key => $value)
        {
            $element = $document->createElement('property', $value);
            $element->setAttribute('name', $key);
            $item->appendChild($element);
        }

        if($includeBody)
        {
            return $document->saveXML();
        }
        else
        {
            return $item->C14N();
        }
    }

    /**
     * @return The item's unique identifier.
     */

    public function __toString()
    {
        return $this->id;
    }

    /**
     * Checks to see if the item is already cached locally and if not reads it
     * from the Directed Edge server.
     */

    private function read()
    {
        if($this->isCached)
        {
            return;
        }

        try
        {
            $content = $this->resource->get();
            $document = new DOMDocument();
            $document->loadXML($content);

            $linkNodes = $document->getElementsByTagName('link');

            for($i = 0; $i < $linkNodes->length; $i++)
            {
                $link = $linkNodes->item($i)->textContent;
                $type = $linkNodes->item($i)->attributes->getNamedItem('type')->value;

                # Don't overwrite links that the user has created.

                if(!isset($this->links[$type][$link]))
                {
                    $weight = $linkNodes->item($i)->attributes->getNamedItem('weight')->value;
                    $this->links[$type][$link] = $weight ? $weight : 0;
                }
            }

            $this->tags =
                $this->getValuesByTagName($document, 'tag', null, $this->tags);
            $this->properties =
                $this->getValuesByTagName($document, 'property', 'name', $this->properties);
        }
        catch (DirectedEdgeException $e)
        {
            # If it's a 404 that just means the item hasn't been created yet.

            if($e->getHttpCode() != 404)
            {
                throw $e;
            }
        }

        $this->isCached = true;
    }

    /**
     * @param DOMDocument The document (or element) to search in.
     * @param string The element name to extract.
     * @param string The name of the attribute to use as the key.  If none, then a
     * normal (non-hash) array is created.
     * @param array Existing values.  Will not be overwritten if they exits.
     */

    public static function getValuesByTagName($document, $element, $attribute = null,
                                              $values = array())
    {
        $nodes = $document->getElementsByTagName($element);

        for($i = 0; $i < $nodes->length; $i++)
        {
            if($attribute)
            {
                $key = $nodes->item($i)->attributes->getNamedItem($attribute)->textContent;

                if(!isset($values[$key]))
                {
                    $values[$key] = $nodes->item($i)->textContent;
                }
            }
            else
            {
                $value = $nodes->item($i)->textContent;

                if(!in_array($value, $values))
                {
                    $values[] = $nodes->item($i)->textContent;
                }
            }
        }

        return $values;
    }

    public static function mergeOptions($tags, $options, $linkWeights)
    {
        foreach($linkWeights as $type => $weight)
        {
            if($type == '')
            {
                $type = 'default';
            }

            $options["${type}Weight"] = $weight;
        }

        $options[tags] = is_array($tags) ? implode(",", $tags) : $tags;

        return $options;
    }

    private function query($method, $tags = array(), $options = array(), $linkWeights = array())
    {
        $content = $this->resource->get(
            $method, $this->mergeOptions($tags, $options, $linkWeights));

        $document = new DOMDocument();
        $document->loadXML($content);

        return $this->getValuesByTagName($document, $method);
    }
}

/**
 * A very simple class for creating Directed Edge XML files or exporting items
 * in batch to a DirectedEdgeDatabase.  This can be done for example with:
 *
 * <code>
 * $exporter = new DirectedEdgeExporter('mydatabase.xml');
 * $item = new DirectedEdgeItem($exporter->getDatabase(), 'product_1');
 * $item->addTag('product');
 * $exporter->export($item);
 * $exporter->finish();
 * </code>
 *
 * <tt>mydatabase.xml</tt> now contains:
 *
 * <?xml version="1.0" encoding="UTF-8"?>
 * <directededge version="0.1">
 * <item id='product_1'><tag>product</tag></item>
 * </directededge>
 *
 * Which can then be imported to a database on the server with:
 *
 * <code>
 * $database = new DirectedEdgeDatabase('mydatabase', 'mypassword');
 * $database->import('mydatabase.xml');
 * </code>
 *
 * Items may also be exported from existing databases.
 *
 * Alternatively (in smaller batches) you can export items directly to
 * a DirectedEdgeDatabase:
 *
 * <code>
 * $database = new DirectedEdgeDatabase('user', 'pass');
 * $exporter = new DirectedEdgeExporter($database);
 * $item = new DirectedEdgeItem($database, 'product_1');
 * $item->addTag('product');
 * $exporter->export($item);
 * $exporter->finish();
 * </code>
 */

class DirectedEdgeExporter
{
    private $database;
    private $file = null;
    private $data = "";

    /**
     * @param string The file name or database to export the data to.
     */

    public function __construct($destination)
    {
        if(is_string($destination))
        {
            $this->database = new DirectedEdgeDatabase('export');
            $this->file = fopen($destination, 'w');
        }
        else if(is_a($destination, "DirectedEdgeDatabase"))
        {
            $this->database = $destination;
        }
        else
        {
            throw new Exception("Exporter destination must be a file name or database object.");
        }

        $this->write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\n");
        $this->write("<directededge version=\"0.1\">\n");
    }

    /**
     * @return DirectedEdgeDatabase The database backing the exporter.  If the
     * exporter is outputting to a file, this is a dummy database.
     */

    public function getDatabase()
    {
        return $this->database;
    }

    /**
     * @param DirectedEdgeItem An item to be added to the XML output from the exporter.
     */

    public function export($item)
    {
        $this->write($item->toXML(null, null, null, false) . "\n");
    }

    /**
     * If the exporter is exporting to a file, then this tells the exporter to
     * finish up the XML output and close the output file.
     *
     * If the exporter is exporting to a database, this adds the updated content
     * and writes it to the database and resets the internal storage for item
     * content.
     */

    public function finish()
    {
        $this->write("</directededge>\n");

        if($this->file)
        {
            fclose($this->file);
        }
        else
        {
            $this->database->resource()->put($this->data, "add?createMissingLinks=true");
            $this->data = "";
        }
    }

    private function write($data)
    {
        if($this->file)
        {
            fwrite($this->file, $data);
        }
        else
        {
            $this->data .= $data;
        }
    }
}

?>
