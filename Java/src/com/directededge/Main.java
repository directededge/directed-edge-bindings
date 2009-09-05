package com.directededge;

import java.util.Map;

public class Main
{
    public static void main(String[] args)
    {
        Database db = new Database("testdb", "test");
        Item item = new Item(db, "Socrates");
        
        Map<String, Integer> links = item.getLinks();

        System.out.println(links.size());

        for(String key : links.keySet())
        {
            System.out.println(key);
        }

        Exporter exporter = new Exporter("test.xml");
        exporter.export(new Item(exporter.getDatabase(), "foo"));
        exporter.finish();
    }
}
