/*
 * Copyright (C) 2009-2016 Directed Edge, Inc.
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

package com.directededge;

import com.directededge.Database.ResourceException;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.StringWriter;
import java.util.ArrayList;
import java.util.Arrays;
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
import org.apache.commons.lang3.StringUtils;
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
    private Map<String, Map<String, Integer>> links;
    private Set<String> tags;
    private Map<String, String> properties;
    private Map<String, Set<String>> linksToRemove;
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
        links = new HashMap<String, Map<String, Integer>>();
        tags = new HashSet<String>();
        properties = new HashMap<String, String>();
        linksToRemove = new HashMap<String, Set<String>>();
        tagsToRemove = new HashSet<String>();
        propertiesToRemove = new HashSet<String>();
    }

    /**
     * Items have a unique identifier which is passed into the constructor.
     * This returns the unique identifier for this item.
     *
     * @return The unique identifier for the item.
     */
    public String getName()
    {
        return id;
    }

    /**
     * A map from link-name to link-weight for the items linked from this
     * item.
     *
     * @return A map of links and their respective weights for the item.
     * A weight of zero indicates an unweighted link.
     * @see #linkTo(com.directededge.Item)
     * @see #linkTo(java.lang.String)
     * @see #linkTo(com.directededge.Item, int)
     * @see #linkTo(java.lang.String, int)
     * @see #unlinkFrom(com.directededge.Item)
     * @see #unlinkFrom(java.lang.String)
     */
    public Map<String, Map<String, Integer>> getLinks()
    {
        read();
        return links;
    }

    public Map<String, Integer> getLinks(String linkType)
    {
        read();
        if(!links.containsKey(linkType))
        {
            return new HashMap<String, Integer>();
        }
        return links.get(linkType);
    }

    /**
     * Creates an unweighted link.
     *
     * @param other The ID of another item in the database.
     * @see #unlinkFrom(com.directededge.Item)
     * @see #unlinkFrom(java.lang.String)
     */
    public void linkTo(String other)
    {
        linkTo(other, 0);
    }

    /**
     * Creates a weighted link from this item to other.
     *
     * @param other The ID of another item in the database.
     * @param weight A weight, 1-10 or 0 for no weight for the link.
     * @see #unlinkFrom(com.directededge.Item)
     * @see #unlinkFrom(java.lang.String)
     */
    public void linkTo(String other, int weight)
    {
        linkTo(other, weight, "");
    }

    /**
     * Creates an unweighted link to other.
     *
     * @param other Another item in the database.
     * @see #unlinkFrom(com.directededge.Item)
     * @see #unlinkFrom(java.lang.String)
     */
    public void linkTo(Item other)
    {
        linkTo(other.getName());
    }

    /**
     * Creates a weighted link from this item to other.
     *
     * @param other Another item in the database.
     * @param weight A weight, 1-10 or 0 for no weight for the link.
     * @see #unlinkFrom(com.directededge.Item)
     * @see #unlinkFrom(java.lang.String)
     */
    public void linkTo(Item other, int weight)
    {
        linkTo(other.getName(), weight);
    }

    public void linkTo(String other, String linkType)
    {
        linkTo(other, 0, linkType);
    }

    public void linkTo(String other, int weight, String linkType)
    {
        if(weight < 0 || weight > 10)
        {
            throw new IllegalArgumentException(
                    "Weights must be in the range of 0 to 10.");
        }

        if(!links.containsKey(linkType))
        {
            links.put(linkType, new HashMap<String, Integer>());
        }

        links.get(linkType).put(other, weight);

        if(linksToRemove.containsKey(linkType))
        {
            linksToRemove.get(linkType).remove(other);
            if(linksToRemove.get(linkType).isEmpty())
            {
                linksToRemove.remove(linkType);
            }
        }
    }

    public void linkTo(Item other, String linkType)
    {
        linkTo(other.getName(), linkType);
    }

    public void linkTo(Item other, int weight, String linkType)
    {
        linkTo(other.getName(), weight, linkType);
    }

    /**
     * Removes a link from this item to other.
     *
     * @param other The ID of another item in the database.
     * @see #linkTo(com.directededge.Item)
     * @see #linkTo(java.lang.String)
     * @see #linkTo(com.directededge.Item, int)
     * @see #linkTo(java.lang.String, int)     */
    public void unlinkFrom(String other)
    {
        unlinkFrom(other, "");
    }

    /**
     * Remove a link from this item to other.
     *
     * @param other Another item in the database.
     * @see #linkTo(com.directededge.Item)
     * @see #linkTo(java.lang.String)
     * @see #linkTo(com.directededge.Item, int)
     * @see #linkTo(java.lang.String, int)
     */
    public void unlinkFrom(Item other)
    {
        unlinkFrom(other.getName());
    }

    public void unlinkFrom(String other, String linkType)
    {
        if(isCached)
        {
            if(links.containsKey(linkType))
            {
                links.get(linkType).remove(other);
            }
        }
        else
        {
            if(!linksToRemove.containsKey(linkType))
            {
                linksToRemove.put(linkType, new HashSet<String>());
            }
            linksToRemove.get(linkType).add(other);
        }
    }

    /**
     * If there is a weight for the item with the identifier specified, return
     * that, otherwise returns zero.
     *
     * @param item The ID of an item that this item is linked to.
     * @return The weight for other if found, or zero if the link is
     * unweighted or no link exists.
     * @see #linkTo(com.directededge.Item)
     * @see #linkTo(java.lang.String)
     * @see #linkTo(com.directededge.Item, int)
     * @see #linkTo(java.lang.String, int)
     */
    public int weightFor(String item)
    {
        return weightFor(item, "");
    }

    /**
     * If there is a weight for the item specified return that, otherwise
     * returns zero.
     *
     * @param item Another item that this item is linked to.
     * @return The weight for other if found, or zero if the link is
     * unweighted or no link exists.
     *
     * @see #linkTo(com.directededge.Item)
     * @see #linkTo(java.lang.String)
     * @see #linkTo(com.directededge.Item, int)
     * @see #linkTo(java.lang.String, int)
     */
    public int weightFor(Item item)
    {
        return weightFor(item.getName());
    }

    public int weightFor(String item, String linkType)
    {
        read();

        if(!links.containsKey(linkType) || !links.get(linkType).containsKey(item))
        {
            return 0;
        }

        return links.get(linkType).get(item);
    }

    /**
     * Gets the set of tags for this item.
     *
     * @return The set of tags on this item.  This set should not be modified
     * directly.
     *
     * @see #addTag(java.lang.String)
     * @see #removeTag(java.lang.String)
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
     * @see #removeTag(java.lang.String)
     * @see #getTags()
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
     * @see #addTag(java.lang.String)
     * @see #getTags()
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
     * Returns a map of key-value pairs for the properties for this item.
     *
     * @return The map of key-value pairs for the properties for this item.
     * This map should not be modified directly.
     * @see #setProperty(java.lang.String, java.lang.String)
     * @see #clearProperty(java.lang.String)
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
     * @see #getProperties()
     * @see #getProperty(java.lang.String)
     * @see #clearProperty(java.lang.String)
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
     * @see #setProperty(java.lang.String, java.lang.String)
     * @see #clearProperty(java.lang.String)
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
     * @see #getProperties()
     * @see #getProperty(java.lang.String)
     * @see #clearProperty(java.lang.String)
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
     * @param tags Items which contain any of the specified tags will be allowed
     * in the result set.
     * @param maxResults The maximum number of items to return.
     * @return A list of item IDs with one or more of the given tags.
     */
    public List<String> getRelated(Set<String> tags, int maxResults)
    {
        HashMap<String, Object> options = new HashMap<String, Object>();
        options.put("maxResults", maxResults);
        options.put("excludeLinked", false);
        return readList(document(resource("related"), options), "related");
    }

    /**
     * A list of similar items.  Note the distinction between "related" and
     * "recommended" -- related items are for instance, for a product or page,
     * whereas "recommended" is used for items recommended for a user.
     *
     * @param tags Items which contain any of the specified tags will be allowed
     * in the result set.
     * @param options A set of options that will be passed on to the web services
     * API. Options include "popularity", "excludeLinked", "maxResults", etc.
     * @return A list of item IDs with one or more of the given tags.
     */
    public List<String> getRelated(Set<String> tags, Map<String, Object> options)
    {
        options.put("tags", StringUtils.join(tags, ','));
        return readList(document(resource("related"), options), "related");
    }

    /**
     * A list of items recommended for this item.  Note the distinction between
     * "related" and "recommended" -- related items are for instance, for a
     * product or page, whereas "recommended" is used for items recommended for
     * a user.
     *
     * @return A list of item IDs with one or more of the given tags.
     */
    public List<String> getRecommended()
    {
        return getRecommended(new HashSet<String>());
    }

    /**
     * A list of items recommended for this item.  Note the distinction between
     * "related" and "recommended" -- related items are for instance, for a
     * product or page, whereas "recommended" is used for items recommended for
     * a user.
     *
     * @param tags Items which contain any of the specified tags will be allowed
     * in the result set.
     * @return A list of item IDs with one or more of the given tags.
     */
    public List<String> getRecommended(Set<String> tags)
    {
        return getRecommended(tags, 20);
    }

    /**
     * A list of items recommended for this item.  Note the distinction between
     * "related" and "recommended" -- related items are for instance, for a
     * product or page, whereas "recommended" is used for items recommended for
     * a user.
     *
     * @param tags Items which contain any of the specified tags will be allowed
     * in the result set.
     * @param maxResults The maximum number of items to return.
     * @return A list of item IDs with one or more of the given tags.
     */
    public List<String> getRecommended(Set<String> tags, int maxResults)
    {
        HashMap<String, Object> options = new HashMap<String, Object>();
        options.put("tags", StringUtils.join(tags, ','));
        options.put("maxResults", maxResults);
        options.put("excludeLinked", true);
        return readList(document(resource("recommended"), options), "recommended");
    }

    /**
     * A list of items recommended for this item.  Note the distinction between
     * "related" and "recommended" -- related items are for instance, for a
     * product or page, whereas "recommended" is used for items recommended for
     * a user.
     *
     * @param tags Items which contain any of the specified tags will be allowed
     * in the result set.
     * @param maxResults The maximum number of items to return.
     * @return A list of item IDs with one or more of the given tags.
     */
    public List<String> getRecommended(Set<String> tags, Map<String, Object> options)
    {
        options.put("tags", StringUtils.join(tags, ','));
        return readList(document(resource("recommended"), options), "recommended");
    }

    /**
     * Saves all changes made to the item back to the database.
     */
    public void save()
    {
        try
        {
            if(isCached)
            {
                database.put(resource(), toXML(Updater.Method.Replace, true));
            }
            else
            {
                database.post(resource(), toXML(Updater.Method.Add, true),
                        options(Updater.Method.Add));

                if(subtractionNeeded())
                {
                    database.post(resource(), toXML(Updater.Method.Subtract, true),
                            options(Updater.Method.Subtract));
                }
            }
        }
        catch (ResourceException ex)
        {
            Logger.getLogger(Item.class.getName()).log(Level.SEVERE,
                    null, ex);
        }
    }

    public void destroy() throws ResourceException
    {
        database.delete(resource());
    }

    /**
     * Converts this item to an XML representation which can be sent to the
     * server.
     *
     * @return An XML representation of the item.
     */
    public String toXML(Updater.Method method, boolean includeDocument)
    {
        if(method == Updater.Method.Add || method == Updater.Method.Replace)
        {
            return toXML(tags, links, properties, false);
        }

        HashMap<String, Map<String, Integer>> linkMap =
                new HashMap<String, Map<String, Integer>>();

        for(String linkType : linksToRemove.keySet())
        {
            if(!linkMap.containsKey(linkType))
            {
                linkMap.put(linkType, new HashMap<String, Integer>());
            }
            for(String link : linksToRemove.get(linkType))
            {
                linkMap.get(linkType).put(link, 0);
            }
        }

        HashMap<String, String> propertyMap =
                new HashMap<String, String>();

        for(String property : propertiesToRemove)
        {
            propertyMap.put(property, "");
        }

        return toXML(tagsToRemove, linkMap, propertyMap, includeDocument);
    }

    private List<String> resource(String... args)
    {
        ArrayList<String> list = new ArrayList<String>(Arrays.asList("items", id));
        list.addAll(Arrays.asList(args));
        return list;
    }

    private Map<String, Object> options(Updater.Method method)
    {
        HashMap<String, Object> options = new HashMap<String, Object>();
        options.put("updateMethod", method.name().toLowerCase());
        return options;
    }

    private boolean subtractionNeeded()
    {
        return (!linksToRemove.isEmpty() ||
                !tagsToRemove.isEmpty() ||
                !propertiesToRemove.isEmpty());
    }

    private String toXML(Set<String> tags, Map<String, Map<String, Integer>> links,
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

            for(String linkType : links.keySet())
            {
                Map<String, Integer> linkMap = links.get(linkType);

                for(String linkName : linkMap.keySet())
                {
                    Element linkElement = doc.createElement("link");
                    linkElement.setTextContent(linkName);

                    if(linkType != null && !linkType.isEmpty())
                    {
                        linkElement.setAttribute("type", linkType);
                    }

                    if(linkMap.get(linkName) > 0)
                    {
                        linkElement.setAttribute("weight", linkMap.get(linkName).toString());
                    }

                    itemElement.appendChild(linkElement);
                }
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

        Document doc = document(resource(), new HashMap<String, Object>());

        NodeList nodes = doc.getElementsByTagName("link");
        for(int i = 0; i < nodes.getLength(); i++)
        {
            int weight = 0;
            String linkType = "";

            Node weightAttribute =
                    nodes.item(i).getAttributes().getNamedItem("weight");

            if(weightAttribute != null)
            {
                weight = Integer.parseInt(weightAttribute.getTextContent());
            }

            Node typeAttribute =
                    nodes.item(i).getAttributes().getNamedItem("type");

            if(typeAttribute != null)
            {
                linkType = typeAttribute.getTextContent();
            }

            String target = nodes.item(i).getTextContent();

            if(!links.containsKey(linkType))
            {
                links.put(linkType, new HashMap<String, Integer>());
            }

            if(!links.get(linkType).containsKey(target))
            {
                links.get(linkType).put(target, weight);
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

    private Document document(List<String> resources, Map<String, Object> options)
    {
        try
        {
            DocumentBuilder builder =
                    documentBuilderFactory.newDocumentBuilder();

            InputStream stream;

            try
            {
                stream = new ByteArrayInputStream(database.get(resources, options).getBytes());
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
}
