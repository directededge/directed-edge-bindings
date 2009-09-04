/*
 * Copyright (C) 2009 Directed Edge, Inc.
 */

package com.directededge;

import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.IOException;
import java.util.logging.Level;
import java.util.logging.Logger;

public class Exporter
{
    private Database database;
    private BufferedWriter output;

    public Exporter(String fileName)
    {
        database = new Database(null, null);

        try
        {
            output = new BufferedWriter(new FileWriter(fileName));
            output.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\n");
            output.write("<directededge version=\"0.1\">\n");
        }
        catch (IOException ex)
        {
            Logger.getLogger(Exporter.class.getName()).log(Level.SEVERE, null, ex);
        }
    }

    public Database getDatabase()
    {
        return database;
    }

    public void export(Item item)
    {
        try
        {
            output.write(item.toXML());
        }
        catch (IOException ex)
        {
            Logger.getLogger(Exporter.class.getName()).log(Level.SEVERE, null, ex);
        }
    }

    public void finish()
    {
        try
        {
            output.write("</directededge>\n");
            output.close();
        }
        catch (IOException ex)
        {
            Logger.getLogger(Exporter.class.getName()).log(Level.SEVERE, null, ex);
        }
    }
}
