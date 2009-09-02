package com.directededge;

public class Main
{

    /**
     * @param args the command line arguments
     */
    public static void main(String[] args)
    {
        Database db = new Database("testdb", "test");
        System.out.println(db.get());
    }
}
