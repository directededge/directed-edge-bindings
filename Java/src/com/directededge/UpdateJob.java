/*
 * Copyright (C) 2012 Directed Edge, Inc.
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
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.util.ArrayList;

public abstract class UpdateJob
{
    public interface Updater
    {
        void update(Item item);
    }

    public enum Method
    {
        Update,
        Replace
    }

    private final String header =
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\n" +
            "<directededge version=\"0.1\">\n";
    private final String footer =
            "</directededge>";

    private class Output
    {
        public File file;
        public BufferedWriter writer;

        Output(String prefix) throws IOException
        {
            file = File.createTempFile("directededge-updatejob-" + prefix, ".xml");
            file.deleteOnExit();
            writer = new BufferedWriter(new FileWriter(file));
            writer.write(header);
        }

        void close() throws IOException
        {
            writer.write(footer);
            writer.flush();
        }
    }

    private final Database database;
    private final Method method;
    private final Output adder;
    private final Output subtracter;

    public UpdateJob(Database database, Method method) throws IOException
    {
        this.database = database;
        this.method = method;
        adder = new Output("add");
        subtracter = (method == Method.Update) ? new Output("subtract") : null;
    }

    public void run() throws IOException, ResourceException
    {
        updateItems();
        push();
    }

    protected abstract void updateItems() throws IOException;

    protected void updateItem(String id, Updater updater) throws IOException
    {
        Item item = new Item(database, id);
        updater.update(item);

        if(item.hasContentFor(Item.UpdateMethod.Add))
        {
            adder.writer.write(item.toXML(Item.UpdateMethod.Add, false));
        }
        if(method == Method.Update && item.hasContentFor(Item.UpdateMethod.Subtract))
        {
            subtracter.writer.write(item.toXML(Item.UpdateMethod.Subtract, false));
        }
    }

    private void push() throws IOException, ResourceException
    {
        adder.close();

        if(method == Method.Update)
        {
            subtracter.close();
        }

        if(method == Method.Replace)
        {
            database.put(adder.file);
        }
        else if(method == Method.Update)
        {
            database.post(new ArrayList<String>(), adder.file,
                    Item.options(Item.UpdateMethod.Add));
            database.post(new ArrayList<String>(), subtracter.file,
                    Item.options(Item.UpdateMethod.Subtract));
        }
    }
}
