<?php

require_once('HTTP/Request2.php');

function array_contains($haystack, $needle)
{
    foreach($haystack as $value)
    {
        if($value == $needle)
        {
            return true;
        }
    }

    return false;
}

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
    if(!array_contains($haystack, $needle))
    {
        $haystack[] = $needle;
    }

    return $haystack;
}

class DirectedEdgeResource
{
    private $base;

    public function __construct($base)
    {
        $this->base = $base;
    }
    
    public function path($path = "")
    {
        return $this->base . '/' . urlencode($path);
    }

    public function get($path = "")
    {
        # print "Get: " . $this->path() . $path . "\n";
        $request = new HTTP_Request2($this->path() . $path);
        $response = $request->send();
        return $response->getBody();
    }

    public function put($content, $path = "")
    {
        $request = new HTTP_Request2($this->path() . $path, HTTP_Request2::METHOD_PUT);
        $request->setBody($content, file_exists($content));
        $response = $request->send();
    }

    public function delete($path = "")
    {
        $request = new HTTP_Request2($this->path() . $path, HTTP_Request2::METHOD_DELETE);
        $response = $request->send();
    }

    public function __toString()
    {
        return $this->base;
    }
}

class DirectedEdgeDatabase
{
    private $resource;

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

    public function resource()
    {
        return $this->resource;
    }

    public function import($fileName)
    {
        $this->resource->put($fileName);
    }
}

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

    public function __construct($database, $id)
    {
        $this->database = $database;
        $this->resource = new DirectedEdgeResource($database->resource()->path($id));
        $this->id = $id;
    }

    public function getName()
    {
        return $this->id;
    }

    public function getLinks()
    {
        $this->read();
        return $this->links;
    }

    public function getTags()
    {
        $this->read();
        return $this->tags;
    }

    public function getProperties()
    {
        $this->read();
        return $this->properties;
    }

    public function getProperty($name)
    {
        $this->read();
        return $this->properties[$name];
    }

    public function setProperty($name, $value)
    {
        unset($this->propertiesToRemove[$name]);
        $this->properties[$name] = $value;
    }

    public function clearProperty($name)
    {
        $this->propertiesToRemove[$name] = "";
        unset($this->properties[$name]);
    }

    public function linkTo($other, $weight = 0)
    {
        ### Throw an error if this is out of range.
        unset($this->linksToRemove[$other]);
        $this->links[$other] = $weight;
    }

    public function unlinkFrom($other)
    {
        $this->linksToRemove[$other] = 0;
        unset($this->links[$other]);
    }

    public function getWeightFor($other)
    {
        $this->read();
        return $this->links[$other];
    }

    public function addTag($tag)
    {
        $this->tagsToRemove = array_remove($this->tagsToRemove, $tag);
        $this->tags = array_insert($this->tags, $tag);
    }

    public function removeTag($tag)
    {
        if(!$this->isCached)
        {
            $this->tagsToRemove = array_insert($this->tagsToRemove, $tag);
        }

        $this->tags = array_remove($this->tags, $tag);
    }

    public function save()
    {
        if($this->isCached)
        {
            $this->resource->put($this->toXML());
        }
        else
        {
            if(!empty($this->links) ||
               !empty($this->tags) ||
               !empty($this->properties))
            {
                $this->resource->put($this->toXML(), 'add');
            }

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

    public function destroy()
    {
        $this->resource->delete();
    }

    public function getRelated($tags = array())
    {
        $content = $this->resource->get('related?tags=' .
                                        (is_array($tags) ? join($tags, ',') : $tags));
        $document = new DOMDocument();
        $document->loadXML($content);
        return $this->getValuesByTagName($document, 'related');
    }

    public function getRecommended($tags = array())
    {
        $content = $this->resource->get('recommended?excludeLinked=true&tags=' .
                                        (is_array($tags) ? join($tags, ',') : $tags));
        $document = new DOMDocument();
        $document->loadXML($content);
        return $this->getValuesByTagName($document, 'recommended');
    }

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

        foreach($links as $name => $weight)
        {
            $element = $document->createElement('link', $name);

            if($links[$name] > 0)
            {
                $element->setAttribute('weight', $weight);
            }

            $item->appendChild($element);
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

    /* PRIVATE */

    private function read()
    {
        if($this->isCached)
        {
            return;
        }

        $content = $this->resource->get();
        $document = new DOMDocument();
        $document->loadXML($content);

        $linkNodes = $document->getElementsByTagName('link');

        for($i = 0; $i < $linkNodes->length; $i++)
        {
            $link = $linkNodes->item($i)->textContent;

            # Don't overwrite links that the user has created.

            if(!isset($this->links[$link]))
            {
                $weight = $linkNodes->item($i)->attributes->getNamedItem('weight');
                $this->links[$link] = $weight ? $weight : 0;
            }
        }

        $this->tags =
            $this->getValuesByTagName($document, 'tag', null, $this->tags);
        $this->properties =
            $this->getValuesByTagName($document, 'property', 'name', $this->properties);

        $this->isCached = true;
    }

    /**
     * @param DOMDocument The document to search in.
     * @param string The element name to extract.
     * @param string The name of the attribute to use as the key.  If none, then a normal (non-hash)
     * array is created.
     * @param array Existing values.  Will not be overwritten if they exits.
     */

    private function getValuesByTagName($document, $element, $attribute = null, $values = array())
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

                if(!array_contains($values, $value))
                {
                    $values[] = $nodes->item($i)->textContent;
                }
            }
        }

        return $values;
    }
}

class DirectedEdgeExporter
{
    private $database;
    private $file;

    public function __construct($fileName)
    {
        $this->database = new DirectedEdgeDatabase('export');
        $this->file = fopen($fileName, 'w');
        fwrite($this->file, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\n");
        fwrite($this->file, "<directededge version=\"0.1\">\n");
    }

    public function getDatabase()
    {
        return $this->database;
    }

    public function export($item)
    {
        fwrite($this->file, $item->toXML(null, null, null, false) . "\n");
    }

    public function finish()
    {
        fwrite($this->file, "</directededge>\n");
        fclose($this->file);
    }
}

?>