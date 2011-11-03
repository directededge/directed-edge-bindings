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

package com.directededge;

import java.io.File;
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.logging.Level;
import java.util.logging.Logger;
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.auth.AuthScope;
import org.apache.http.auth.UsernamePasswordCredentials;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPut;
import org.apache.http.entity.FileEntity;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.DefaultHttpClient;
import org.apache.http.util.EntityUtils;


/**
 * Represents a database on the Directed Edge servers.  A database is simply
 * a collection of items.  See developer.directededge.com for more information
 * on the concepts in place here and throughout the Directed Edge API.
 */

public class Database
{
    public enum Protocol
    {
        HTTP,
        HTTPS
    }
    
    public enum Method
    {
        GET,
        PUT,
        POST,
        DELETE
    }
    
    private String name;
    private String password;
    private String host;
    private Protocol protocol;
    private DefaultHttpClient client;

    /**
     * This is thrown when a resource cannot be read or written for some reason.
     */
    public class ResourceException extends Exception
    {
        public Method method;
        public String url;

        ResourceException(Method method, String url)
        {
            super("Error doing " + method.toString() + " on " + url);
            this.method = method;
            this.url = url;
        }
    }

    /**
     * Initializes a Directed Edge database.  You should have received a user
     * name and account name from Directed Edge.
     *
     * @param protocol The protocol used in communication - supported protocols
     * are HTTP and HTTPS.
     * @param username The user / database name.
     * @param password Your password.
     */
    public Database(Protocol protocol, String username, String password)
    {
        this.protocol = protocol;
        name = username;
        this.password = password;

        host = System.getenv("DIRECTEDEDGE_HOST");
        
        if(host == null)
        {
            host = "webservices.directededge.com";
        }

        client = new DefaultHttpClient();
        
        if(username != null)
        {
            client.getCredentialsProvider().setCredentials(
                    new AuthScope(host, protocol == Protocol.HTTP ? 80 : 443),
                    new UsernamePasswordCredentials(username, password));
        }
    }

    /**
     * Initializes a Directed Edge database.  You should have received a user
     * name and account name from Directed Edge.
     *
     * @param username The user / database name.
     * @param password Your password.
     */
    public Database(String username, String password)
    {
        this(Protocol.HTTP, username, password);
    }

    /**
     * Used to import a Directed Edge XML file.  Usually used in conjunction
     * with the Exporter.
     * @param fileName The file path of a Directed Edge XML file.
     * @see Exporter
     */
    public void importFromFile(String fileName) throws ResourceException
    {
        put("", new FileEntity(new File(fileName), "text/xml"));
    }

    /**
     * Grabs the contents of the sub-resource, e.g. "item1/related".  This is
     * primarily for internal usage.
     *
     * @param resource The subresource to fetch.
     * @return The content of the sub resource.
     * @throws ResourceException Throws a ResourceException if the resource
     * cannot be found, or if there is an authentication error.
     * @see ResourceException
     */
    public String get(String resource) throws ResourceException
    {
        HttpGet request = new HttpGet(url(resource));
        try
        {
            HttpResponse response = client.execute(request);
            return EntityUtils.toString(response.getEntity());
        }
        catch (IOException ex)
        {
            Logger.getLogger(Database.class.getName()).log(Level.SEVERE, null, ex);
        }
        return "";
    }

    /**
     * Grabs the contents of the sub-resource, e.g. "item1".  This is
     * primarily for internal usage.
     *
     * @param resource The subresource to write to.
     */
    public void put(String resource, String data)
    {
        try
        {
            put(resource, new StringEntity(data, "text/xml", "UTF-8"));
        }
        catch (UnsupportedEncodingException ex)
        {
            Logger.getLogger(Database.class.getName()).log(Level.SEVERE, null, ex);
        }
    }
    
    private void put(String resource, HttpEntity entity)
    {
        HttpPut request = new HttpPut(url(resource));
        request.setEntity(entity);
        try
        {
            EntityUtils.consume(client.execute(request).getEntity());
        }
        catch (IOException ex)
        {
            Logger.getLogger(Database.class.getName()).log(Level.SEVERE, null, ex);
        }
    }

    private String url(String resource)
    {
        try
        {
            URL url = new URL(protocol.toString().toLowerCase(), host,
                    "/api/v1/" + name + "/" + resource);
            return url.toString();
        }
        catch (MalformedURLException ex)
        {
            Logger.getLogger(Database.class.getName()).log(Level.SEVERE, null, ex);
            return null;
        }
    }
}
