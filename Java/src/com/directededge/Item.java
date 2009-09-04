/*
 * Copyright (C) 2009 Directed Edge, Inc.
 */

package com.directededge;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.StringWriter;
import java.util.HashMap;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.xml.parsers.*;
import javax.xml.transform.*;
import org.w3c.dom.*;
import org.xml.sax.SAXException;

public class Item
{
    private Database database;
    private String id;
    private boolean isCached;
    private String [] links;
    private String [] tags;
    private HashMap<String, String> properties;

    private final DocumentBuilderFactory documentBuilderFactory =
            DocumentBuilderFactory.newInstance();

    public Item(Database database, String id)
    {
        this.database = database;
        this.id = id;

        isCached = false;
        links = new String[0];
        tags = new String[0];
        properties = new HashMap<String, String>();
    }

    public String getName()
    {
        return id;
    }

    public String [] getLinks()
    {
        read();
        return links;
    }

    public String [] getTags()
    {
        read();
        return tags;
    }

    public HashMap<String, String> getProperties()
    {
        read();
        return properties;
    }

    public String [] getRelated()
    {
        return getRelated(new String[0]);
    }

    public String [] getRelated(String [] tags)
    {
        return getRelated(tags, 20);
    }

    public String [] getRelated(String [] tags, int maxResults)
    {
        return readList(document("related"), "related");
    }

    public String toXML()
    {
        return toXML(tags, links, properties, false);
    }

    public String toXML(String [] tags, String [] links,
            HashMap<String, String> properties, boolean includeDocument)
    {
        try
        {
            Document doc = documentBuilderFactory.newDocumentBuilder().newDocument();
            Element root = doc.createElement("directededge");
            root.setAttribute("version", "0.1");
            Element itemElement = doc.createElement("item");
            itemElement.setAttribute("id", id);

            for(int i = 0; i < tags.length; i++)
            {
                Element tagElement = doc.createElement("tag");
                tagElement.setTextContent(tags[i]);
                itemElement.appendChild(tagElement);
            }

            for(int i = 0; i < links.length; i++)
            {
                Element linkElement = doc.createElement("link");
                linkElement.setTextContent(links[i]);
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

        links = readList(doc, "link");
        tags = readList(doc, "tag");

        NodeList nodes = doc.getElementsByTagName("property");
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
            InputStream stream =
                    new ByteArrayInputStream(database.get(resource).getBytes());

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

    private String [] readList(Document doc, String element)
    {
        NodeList nodes = doc.getElementsByTagName(element);
        String [] values = new String[nodes.getLength()];

        for(int i = 0; i < nodes.getLength(); i++)
        {
            values[i] = nodes.item(i).getTextContent();
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
