package com.directededge;

import java.io.StringWriter;

/*
 * Copyright (C) 2011 Directed Edge, Inc.
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

/**
 * Makes incremental updates to a Directed Edge database.  Updater is used like
 * the Exporter where updates to items are made and then updater.export(item)
 * is called and then all of the changes are pushed live with updater.finish()
 *
 * @note The incremental changes are stored in memory, so some attention should
 * be paid to the number of updates made in one batch.
 */
public class Updater extends Exporter
{
    private StringWriter writer;

    /**
     * @param database The database to be updated.
     */
    public Updater(Database database)
    {
        writer = new StringWriter();
        begin(database, writer);
    }

    /**
     * Pushes the pending changes to the database.
     */
    @Override
    public void finish()
    {
        super.finish();
        getDatabase().put("add", writer.toString());
    }
}
