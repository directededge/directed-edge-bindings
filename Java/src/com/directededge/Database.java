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
import org.restlet.data.Method;
import org.restlet.data.Protocol;
import org.restlet.data.Request;

public class Database
{
    private String name;
    private String password;
    private String host;
    private String protocol;
    private Client client;

    public Database(String username, String password)
    {
        protocol = "http";
        name = username;
        this.password = password;

        host = System.getenv("DIRECTEDEDGE_HOST");
        
        if(host == null)
        {
            // host = "webservices.directededge.com";
            host = "localhost";
        }

        client = new Client(Protocol.HTTP);
    }

    public String get(String resource)
    {
        Request request = new Request(Method.GET, url(resource));
        request.setChallengeResponse(
                new ChallengeResponse(ChallengeScheme.HTTP_BASIC, name, password));
        try
        {
            System.out.println(url(resource));
            return client.handle(request).getEntity().getText();
        }
        catch(IOException ex)
        {
            return "";
        }
    }

    private String url(String resource)
    {
        try
        {
            URL url = new URL(protocol, host, "/api/v1/" + name + "/" + resource);
            return url.toString();
        }
        catch (MalformedURLException ex)
        {
            Logger.getLogger(Database.class.getName()).log(Level.SEVERE, null, ex);
            return "";
        }
    }
}
