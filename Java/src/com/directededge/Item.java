/*
 * Copyright (C) 2009 Directed Edge, Inc.
 */

package com.directededge;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.StringReader;
import java.util.HashMap;
import java.util.logging.Level;
import java.util.logging.Logger;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import org.restlet.Application;
import org.w3c.dom.Document;
import org.w3c.dom.NodeList;
import org.xml.sax.InputSource;
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
    }

    public String name()
    {
        return id;
    }

    public String [] links()
    {
        read();
        return links;
    }

    public String [] tags()
    {
        read();
        return tags;
    }

    public HashMap<String, String> properties()
    {
        read();
        return properties;
    }

    private void read()
    {
        try
        {
            if(isCached)
            {
                return;
            }

            DocumentBuilder builder = documentBuilderFactory.newDocumentBuilder();
            InputStream stream = new ByteArrayInputStream(database.get(id).getBytes());
            Document doc = builder.parse(stream);

            isCached = true;
        }
        catch (ParserConfigurationException ex)
        {
            Logger.getLogger(Item.class.getName()).log(Level.SEVERE, null, ex);
        }
        catch (SAXException ex)
        {
            Logger.getLogger(Item.class.getName()).log(Level.SEVERE, null, ex);
        }
        catch (IOException ex)
        {
            Logger.getLogger(Item.class.getName()).log(Level.SEVERE, null, ex);
        }
    }
}
