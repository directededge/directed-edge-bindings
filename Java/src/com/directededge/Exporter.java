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

import java.io.BufferedWriter;
import java.io.FileWriter;
import java.io.IOException;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.Writer;
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
     * Creates an exporter that will store items in stream.
     *
     * @param stream An output stream where the exported data should be stored.
     * @see #finish()
     */
    public Exporter(OutputStream stream)
    {
        begin(new OutputStreamWriter(stream));
    }

    /**
     * Creates an exporter that will store items in fileName.
     * @param fileName The file path where the resulting XML file should be
     * stored.
     * @see #finish()
     */
    public Exporter(String fileName)
    {
        try
        {
            begin(new FileWriter(fileName));
        }
        catch (IOException ex)
        {
            Logger.getLogger(Exporter.class.getName()).log(Level.SEVERE, null, ex);
        }
    }

    protected Exporter()
    {

    }

    /**
     * Returns a pseudo-database that can be passed into the constructor of new
     * Item instances to be exported.
     *
     * @return The database pseudo-database instance.
     * @see Item
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
            output.write(item.toXML(Item.UpdateMethod.valueOf(method().toString()), false) + "\n");
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

    final protected void begin(Database database, Writer writer)
    {
        this.database = database;

        try
        {
            output = new BufferedWriter(writer);
            output.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\n");
            output.write("<directededge version=\"0.1\">\n");
        }
        catch (IOException ex)
        {
            Logger.getLogger(Exporter.class.getName()).log(Level.SEVERE, null, ex);
        }
    }

    private void begin(Writer writer)
    {
        begin(new Database(null, null), writer);
    }

    protected Updater.Method method()
    {
        return Updater.Method.Replace;
    }
}
