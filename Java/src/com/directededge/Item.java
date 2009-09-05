/*
 * Copyright (C) 2009 Directed Edge, Inc.
 */

package com.directededge;

import com.directededge.Database.ResourceNotFoundException;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.StringWriter;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.OutputKeys;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

public class Item
{
    private Database database;
    private String id;
    private boolean isCached;
    private Map<String, Integer> links;
    private Set<String> tags;
    private Map<String, String> properties;

    private final DocumentBuilderFactory documentBuilderFactory =
            DocumentBuilderFactory.newInstance();

    public Item(Database database, String id)
    {
        this.database = database;
        this.id = id;

        isCached = false;
        links = new HashMap<String, Integer>();
        tags = new HashSet<String>();
        properties = new HashMap<String, String>();
    }

    public String getName()
    {
        return id;
    }

    public Map<String, Integer> getLinks()
    {
        read();
        return links;
    }

    public Set<String> getTags()
    {
        read();
        return tags;
    }

    public Map<String, String> getProperties()
    {
        read();
        return properties;
    }

    public List<String> getRelated()
    {
        return getRelated(new String[0]);
    }

    public List<String> getRelated(String [] tags)
    {
        return getRelated(tags, 20);
    }

    public List<String> getRelated(String [] tags, int maxResults)
    {
        return readList(document("related"), "related");
    }

    public String toXML()
    {
        return toXML(tags, links, properties, false);
    }

    public String toXML(Set<String> tags, Map<String, Integer> links,
            Map<String, String> properties, boolean includeDocument)
    {
        try
        {
            Document doc = documentBuilderFactory.newDocumentBuilder().newDocument();
            Element root = doc.createElement("directededge");
            root.setAttribute("version", "0.1");
            Element itemElement = doc.createElement("item");
            itemElement.setAttribute("id", id);

            for(String tag : tags)
            {
                Element tagElement = doc.createElement("tag");
                tagElement.setTextContent(tag);
                itemElement.appendChild(tagElement);
            }

            for(String linkName : links.keySet())
            {
                Element linkElement = doc.createElement("link");
                linkElement.setTextContent(linkName);
                itemElement.appendChild(linkElement);
            }

            for(String key : properties.keySet())
            {
                Element propertyElement = doc.createElement("property");
                propertyElement.setAttribute("name", key);
                propertyElement.setTextContent(properties.get(key));
                itemElement.appendChild(propertyElement);
            }

            root.appendChild(itemElement);

            return includeDocument ? toString(root) : toString(itemElement);
        }
        catch (ParserConfigurationException ex)
        {
            Logger.getLogger(Item.class.getName()).log(Level.SEVERE, null, ex);
        }
        return "";
    }

    private void read()
    {
        if(isCached)
        {
            return;
        }

        Document doc = document(id);

        links.clear();
        NodeList nodes = doc.getElementsByTagName("link");
        for(int i = 0; i < nodes.getLength(); i++)
        {
            int weight = 0;

            Node weightAttribute =
                    nodes.item(i).getAttributes().getNamedItem("weight");
            if(weightAttribute != null)
            {
                weight = Integer.parseInt(weightAttribute.getTextContent());
            }

            links.put(nodes.item(i).getTextContent(), weight);
        }

        tags = new HashSet(readList(doc, "tag"));

        nodes = doc.getElementsByTagName("property");
        properties.clear();
        for(int i = 0; i < nodes.getLength(); i++)
        {
            Node node = nodes.item(i);
            Node attribute = node.getAttributes().getNamedItem("name");

            if(attribute != null)
            {
                properties.put(attribute.getTextContent(), node.getTextContent());
            }
        }

        isCached = true;
    }

    private Document document(String resource)
    {
        try
        {
            DocumentBuilder builder =
                    documentBuilderFactory.newDocumentBuilder();
            InputStream stream;
            try
            {
                stream = new ByteArrayInputStream(database.get(resource).getBytes());
            }
            catch (ResourceNotFoundException ex)
            {
                return builder.newDocument();
            }

            return builder.parse(stream);
        }
        catch (SAXException ex)
        {
            Logger.getLogger(Item.class.getName()).log(Level.SEVERE, null, ex);
        }
        catch (IOException ex)
        {
            Logger.getLogger(Item.class.getName()).log(Level.SEVERE, null, ex);
        }
        catch (ParserConfigurationException ex)
        {
            Logger.getLogger(Item.class.getName()).log(Level.SEVERE, null, ex);
        }

        return null;
    }

    private List<String> readList(Document doc, String element)
    {
        NodeList nodes = doc.getElementsByTagName(element);
        List<String> values = new LinkedList<String>();

        for(int i = 0; i < nodes.getLength(); i++)
        {
            values.add(nodes.item(i).getTextContent());
        }

        return values;
    }

    private String toString(Node node)
    {
        try
        {
            DOMSource domSource = new DOMSource(node);
            StringWriter writer = new StringWriter();
            StreamResult result = new StreamResult(writer);
            TransformerFactory factory = TransformerFactory.newInstance();
            Transformer transformer = factory.newTransformer();
            transformer.setOutputProperty(OutputKeys.OMIT_XML_DECLARATION, "yes");
            transformer.transform(domSource, result);
            return writer.toString();
        }
        catch(TransformerException ex)
        {
            ex.printStackTrace();
            return null;
        }
    }
}
