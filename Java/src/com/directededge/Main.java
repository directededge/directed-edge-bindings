package com.directededge;

public class Main
{
    public static void main(String[] args)
    {
        Database db = new Database("testdb", "test");
        Item item = new Item(db, "Socrates");
        item.links();
    }
}
