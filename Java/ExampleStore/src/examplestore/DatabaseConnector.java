package examplestore;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

public class DatabaseConnector
{
    private final String databaseURL = "jdbc:mysql://localhost:3306/examplestore";
    private final String databaseUser = "root";
    private final String databasePassword = "";

    private Connection connection;

    public DatabaseConnector() throws SQLException
    {
        connection = DriverManager.getConnection(databaseURL, databaseUser, databasePassword);
    }

    public List<Integer> getCustomerIDs() throws SQLException
    {
        return getIDs("customers");
    }

    public List<Integer> getProductIDs() throws SQLException
    {
        return getIDs("products");
    }

    public List<Integer> getProductIDsForCustomerID(int id) throws SQLException
    {
        PreparedStatement statement = connection.prepareStatement(
                "select product from purchases where customer = ?");
        statement.setInt(1, id);
        return integerColumnAsList(statement.executeQuery());
    }

    private List<Integer> getIDs(String table) throws SQLException
    {
        Statement statement = connection.createStatement();
        ResultSet results = statement.executeQuery("select id from " + table);
        return integerColumnAsList(results);
    }

    private List<Integer> integerColumnAsList(ResultSet results) throws SQLException
    {
        ArrayList<Integer> values = new ArrayList<Integer>();

        while(results.next())
        {
            values.add(results.getInt(1));
        }

        return values;
    }
}
