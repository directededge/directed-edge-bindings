package com.directededge;

public class Main
{
    public static void main(String[] args)
    {
        Database db = new Database("testdb", "test");
        System.out.println(db.get());
    }
}
