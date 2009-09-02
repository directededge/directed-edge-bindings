/*
 * Copyright (C) 2008 Directed Edge, Inc.
 */

package com.directededge;

import java.io.IOException;
import org.restlet.Client;
import org.restlet.data.Protocol;


public class Database
{
    private String username;
    private String password;

    private final String protocol = "http";
    private final String host = "webservices.directededge.com";

    private Client client;

    public Database(String username, String password)
    {
        this.username = username;
        this.password = password;
        this.client = new Client(Protocol.HTTP);
    }

    public String get()
    {
        try
        {
            return client.get(protocol + "://" + host).getEntity().getText();
        }
        catch(IOException ex)
        {
            return "";
        }
    }
}
