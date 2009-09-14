/*
 * Copyright (C) 2009 Directed Edge, Inc.
 */

package com.directededge;

import com.directededge.Database.ResourceException;
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
import org.restlet.data.Reference;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

/**
 *  An item in a Directed Edge database
 *
 * There are of a collection of methods here for reading and writing to items.
 * In general as few reads from the remote database as required will be used,
 * specifically items cache all values when any of them are read and writes
 * will not be made to the remote database until save() is called.
 */
public class Item
{
    private Database database;
    private String id;
    private boolean isCached;
    private Map<String, Integer> links;
    private Set<String> tags;
    private Map<String, String> properties;
    private Set<String> linksToRemove;
    private Set<String> tagsToRemove;
    private Set<String> propertiesToRemove;

    private final DocumentBuilderFactory documentBuilderFactory =
            DocumentBuilderFactory.newInstance();

    /**
     * Creates a reference to an item in the Directed Edge database.
     * If the item does not exist it will be created when save() is called.
     * Items are referred to by a unique identifier.
     *
     * @param database The database that this item belongs to.
     * @param id The unique identifier for the item.
     */
    public Item(Database database, String id)
    {
        this.database = database;
        this.id = id;

        isCached = false;
        links = new HashMap<String, Integer>();
        tags = new HashSet<String>();
        properties = new HashMap<String, String>();
        linksToRemove = new HashSet<String>();
        tagsToRemove = new HashSet<String>();
        propertiesToRemove = new HashSet<String>();
    }

    /**
     * @return The unique identifier for the item.
     */
    public String getName()
    {
        return id;
    }

    /**
     * @return A map of links and their respective weights for the item.
     * A weight of zero indicates an unweighted link.
     * @see linkTo()
     * @see unlinkFrom()
     */
    public Map<String, Integer> getLinks()
    {
        read();
        return links;
    }

    /**
     * Creates an unweighted link.
     * @param other The ID of another item in the database.
     * @see unlinkFrom()
     */
    public void linkTo(String other)
    {
        linkTo(other, 0);
    }

    /**
     * Creates a weighted link from this item to @a other.
     * @param other The ID of another item in the database.
     * @param weight A weight, 1-10 or 0 for no weight for the link.
     * @see unlinkFrom()
     */
    public void linkTo(String other, int weight)
    {
        links.put(other, weight);
        linksToRemove.remove(other);
    }

    /**
     * Creates an unweighted link to @a other.
     * @param other Another item in the database.
     * @see unlinkFrom()
     */
    public void linkTo(Item other)
    {
        linkTo(other.getName());
    }

    /**
     * Creates a weighted link from this item to @a other.
     * @param other Another item in the database.
     * @param weight A weight, 1-10 or 0 for no weight for the link.
     * @see unlinkFrom()
     */
    public void linkTo(Item other, int weight)
    {
        linkTo(other.getName(), weight);
    }

    /**
     * Removes a link from this item to @a other.
     * @param other The ID of another item in the database.
     * @see linkTo()
     */
    public void unlinkFrom(String other)
    {
        if(isCached)
        {
            links.remove(other);
        }
        else
        {
            linksToRemove.add(other);
        }
    }

    /**
     * Remove a link from this item to @a other.
     * @param other Another item in the database.
     * @see linkTo()
     */
    public void unlinkFrom(Item other)
    {
        unlinkFrom(other.getName());
    }

    /**
     * @param other The ID of an item that this item is linked to.
     * @return The weight for @a other if found, or zero if the link is
     * unweighted or no link exists.
     * @see linkTo()
     */
    public int weightFor(String other)
    {
        read();
        return links.containsKey(other) ? links.get(other) : 0;
    }

    /**
     * @param other Another item that this item is linked to.
     * @return The weight for @a other if found, or zero if the link is
     * unweighted or no link exists.
     *
     * @see linkTo()
     */
    public int weightFor(Item item)
    {
        return weightFor(item.getName());
    }

    /**
     * @return The set of tags on this item.  This set should not be modified
     * directly.
     *
     * @see addTag()
     * @see removeTag()
     */
    public Set<String> getTags()
    {
        read();
        return tags;
    }

    /**
     * Adds a tag to this item.  The changes are not saved to the database until
     * save() is called.
     *
     * @param name The name of a tag to add to this item.
     * @see remvoeTag()
     * @see getTags()
     */
    public void addTag(String name)
    {
        tags.add(name);
        tagsToRemove.remove(name);
    }

    /**
     * Removes a tag from this item.  The changes are not saved to the database
     * until save() is called.
     *
     * @param name The name of a tag to remove from this item.
     * @see addTag()
     * @see getTags()
     */
    public void removeTag(String name)
    {
        if(isCached)
        {
            tags.remove(name);
        }
        else
        {
            tagsToRemove.add(name);
        }
    }

    /**
     * @return The map of key-value pairs for the properties for this item.
     * This map should not be modified directly.
     * @see setProperty()
     * @see clearProperty()
     */
    public Map<String, String> getProperties()
    {
        read();
        return properties;
    }

    /**
     * Sets a property, a key-value pair, for this item.  The changes are not
     * saved to the database until save() is called.
     *
     * @param name The key for the property.
     * @param value The value.
     * @see getProperties()
     * @see getProperty()
     * @see clearProperty()
     */
    public void setProperty(String name, String value)
    {
        properties.put(name, value);
        propertiesToRemove.remove(name);
    }

    /**
     * Fetches a single proeprty for the item.
     *
     * @param name The property to be fetched.
     * @return The value of the property.
     * @see setProperty()
     * @see clearProperty()
     */
    public String getProperty(String name)
    {
        return getProperties().get(name);
    }

    /**
     * Removes a property from the item.  The changes are not saved to the
     * database until save() is called.
     *
     * @param name The key of the property to be removed.
     * @see getProperties()
     * @see getProperty()
     * @see clearProperty()
     */
    public void clearProperty(String name)
    {
        if(isCached)
        {
            properties.remove(name);
        }
        else
        {
            propertiesToRemove.add(name);
        }
    }

    /**
     * A list of similar items.  Note the distinction between "related" and
     * "recommended" -- related items are for instance, for a product or page,
     * whereas "recommended" is used for items recommended for a user.
     *
     * @return A list of item IDs related to this item.
     */
    public List<String> getRelated()
    {
        return getRelated(new HashSet<String>());
    }

    /**
     * A list of similar items.  Note the distinction between "related" and
     * "recommended" -- related items are for instance, for a product or page,
     * whereas "recommended" is used for items recommended for a user.
     *
     * @param tags Tags used in filtering the results.
     * @return A list of item IDs with one or more of the given tags.
     */
    public List<String> getRelated(Set<String> tags)
    {
        return getRelated(tags, 20);
    }

    /**
     * A list of similar items.  Note the distinction between "related" and
     * "recommended" -- related items are for instance, for a product or page,
     * whereas "recommended" is used for items recommended for a user.
     *
     * @param tags Tags used in filtering the results.
     * @param maxResults The maximum number of items to return.
     * @return A list of item IDs with one or more of the given tags.
     * @return
     */
    public List<String> getRelated(Set<String> tags, int maxResults)
    {
        return readList(document(Reference.encode(id) + "/related" +
                queryString(tags, false, maxResults)), "related");
    }

    public List<String> getRecommended()
    {
        return getRecommended(new HashSet<String>());
    }

    public List<String> getRecommended(Set<String> tags)
    {
        return getRecommended(tags, 20);
    }

    public List<String> getRecommended(Set<String> tags, int maxResults)
    {
         return readList(document(Reference.encode(id) + "/recommended" +
                 queryString(tags, true, maxResults)), "recommended");
    }

    /**
     * Saves all changes made to the item back to the database.
     */
    public void save()
    {
        if(isCached)
        {
            database.put(Reference.decode(id), toXML());
        }
        else
        {
            database.put(Reference.encode(id) + "/add", toXML());
            if(!linksToRemove.isEmpty() ||
               !tagsToRemove.isEmpty() ||
               !propertiesToRemove.isEmpty())
            {
                HashMap linkMap = new HashMap<String, Integer>();
                for(String link : linksToRemove)
                {
                    linkMap.put(link, 0);
                }

                HashMap propertyMap = new HashMap<String, String>();
                for(String property : propertiesToRemove)
                {
                    propertyMap.put(property, "");
                }

                database.put(Reference.encode(id) + "/remove",
                        toXML(tagsToRemove, linkMap, propertyMap, true));
            }
        }
    }

    /**
     * @return An XML representation of the item.
     */
    public String toXML()
    {
        return toXML(tags, links, properties, false);
    }

    private String toXML(Set<String> tags, Map<String, Integer> links,
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
                if(links.get(linkName) > 0)
                {
                    linkElement.setAttribute("weight", links.get(linkName).toString());
                }
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

            return includeDocument ? toString(root, false) : toString(itemElement, true);
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

        Document doc = document(Reference.encode(id));

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

            String target = nodes.item(i).getTextContent();

            if(!links.containsKey(target))
            {
                links.put(target, weight);
            }
        }

        tags.addAll(readList(doc, "tag"));

        nodes = doc.getElementsByTagName("property");
        for(int i = 0; i < nodes.getLength(); i++)
        {
            Node node = nodes.item(i);
            Node attribute = node.getAttributes().getNamedItem("name");

            if(attribute != null &&
               !properties.containsKey(attribute.getTextContent()))
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
            catch (ResourceException ex)
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

    private String toString(Node node, boolean omitXmlDeclaration)
    {
        try
        {
            DOMSource domSource = new DOMSource(node);
            StringWriter writer = new StringWriter();
            StreamResult result = new StreamResult(writer);
            TransformerFactory factory = TransformerFactory.newInstance();
            Transformer transformer = factory.newTransformer();
            if(omitXmlDeclaration)
            {
                transformer.setOutputProperty(OutputKeys.OMIT_XML_DECLARATION, "yes");
            }
            transformer.transform(domSource, result);
            return writer.toString();
        }
        catch(TransformerException ex)
        {
            ex.printStackTrace();
            return null;
        }
    }

    private String queryString(Set<String> tags, boolean excludeLinked,
            int maxResults)
    {
        String query = "?tags=";

        for(String tag : tags)
        {
            query += tag + ",";
        }

        if(tags.size() > 0)
        {
            query = query.substring(0, query.length() - 1);
        }

        query += "&excludeLinked=" + Boolean.toString(excludeLinked);
        query += "&maxResults=" + Integer.toString(maxResults);

        return query;
    }
}
