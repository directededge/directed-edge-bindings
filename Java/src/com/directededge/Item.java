/*
 * Copyright (C) 2009 Directed Edge, Inc.
 */

package com.directededge;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.HashMap;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import org.w3c.dom.Document;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
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
        throw new UnsupportedOperationException("Not yet implemented");
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
            DocumentBuilder builder = documentBuilderFactory.newDocumentBuilder();
            InputStream stream = new ByteArrayInputStream(database.get(resource).getBytes());
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
}
