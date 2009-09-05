/*
 * Copyright (C) 2009 Directed Edge, Inc.
 */

package com.directededge;

import java.io.IOException;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.logging.Level;
import java.util.logging.Logger;
import org.restlet.Client;
import org.restlet.data.ChallengeResponse;
import org.restlet.data.ChallengeScheme;
import org.restlet.data.MediaType;
import org.restlet.data.Method;
import org.restlet.data.Protocol;
import org.restlet.data.Request;
import org.restlet.data.Response;
import org.restlet.resource.FileRepresentation;
import org.restlet.resource.StringRepresentation;

/**
 * Represents a database on the Directed Edge servers.  A database is simply
 * a collection of items.  See developer.directededge.com for more information
 * on the concepts in place here and throughout the Directed Edge API.
 */

public class Database
{
    private String name;
    private String password;
    private String host;
    private Protocol protocol;
    private Client client;

    /**
     * This is thrown when a resource cannot be read or written for some reason.
     */
    public class ResourceException extends Exception
    {
        public Method method;
        public String url;

        ResourceException(Method method, String url)
        {
            super("Error doing " + method.getName() + " on " + url);
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

        client = new Client(Protocol.HTTP);
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
    public void importFromFile(String fileName)
    {
        Request request = new Request(Method.PUT, url(""),
                new FileRepresentation(fileName, MediaType.TEXT_XML));
        request.setChallengeResponse(
                new ChallengeResponse(ChallengeScheme.HTTP_BASIC, name, password));
        client.handle(request);
    }

    /**
     * @internal
     */
    public String get(String resource) throws ResourceException
    {
        Request request = new Request(Method.GET, url(resource));
        request.setChallengeResponse(
                new ChallengeResponse(ChallengeScheme.HTTP_BASIC, name, password));
        Response response = client.handle(request);

        if(response.getStatus().isSuccess())
        {
            try
            {
                return response.getEntity().getText();
            }
            catch (IOException ex)
            {
                Logger.getLogger(Database.class.getName()).log(Level.SEVERE, null, ex);
                return null;
            }
        }
        else
        {
            throw new ResourceException(Method.GET, url(resource));
        }
    }

    /**
     * @internal
     */
    public void put(String resource, String data)
    {
        Request request = new Request(Method.PUT, url(resource),
                new StringRepresentation(data, MediaType.TEXT_XML));
        request.setChallengeResponse(
                new ChallengeResponse(ChallengeScheme.HTTP_BASIC, name, password));
        Response response = client.handle(request);
    }

    private String url(String resource)
    {
        try
        {
            URL url = new URL(protocol.getName(), host, "/api/v1/" + name + "/" + resource);
            return url.toString();
        }
        catch (MalformedURLException ex)
        {
            Logger.getLogger(Database.class.getName()).log(Level.SEVERE, null, ex);
            return null;
        }
    }
}
