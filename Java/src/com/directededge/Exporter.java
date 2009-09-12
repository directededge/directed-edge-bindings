/*
 * Copyright (C) 2009 Directed Edge, Inc.
 */

package com.directededge;

import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.IOException;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 * A utility class to export a collection of items to an XML file to later be
 * imported to a Directed Edge database.  This is usually the first step in
 * adding existing site data to a Directed Edge database.  Typically this will
 * be used in conjunction with an SQL connector to pull items from a site's
 * database and put them into Directed Edge's data format.
 */
public class Exporter
{
    private Database database;
    private BufferedWriter output;

    /**
     * Creates an exporter that will store items in @a fileName.
     * @param fileName The file path where the resulting XML file should be
     * stored.
     * @see finish()
     */
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

    /**
     * @return A pseudo-database that should be used as the database for items
     * created to be used with the exporter.
     */
    public Database getDatabase()
    {
        return database;
    }

    /**
     * Exports an item to the XML file.
     * @param item The item to be exported.
     */
    public void export(Item item)
    {
        try
        {
            output.write(item.toXML() + "\n");
        }
        catch (IOException ex)
        {
            Logger.getLogger(Exporter.class.getName()).log(Level.SEVERE, null, ex);
        }
    }

    /**
     * Must be called when exporting is finished to flush items to the file and
     * finish up the XML document.
     */
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
