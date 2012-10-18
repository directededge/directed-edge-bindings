package examplestore;

import com.directededge.Database;
import com.directededge.Database.ResourceException;
import com.directededge.Item;
import com.directededge.UpdateJob;
import java.io.IOException;
import java.sql.SQLException;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

public class ExampleStore
{
    private final DatabaseConnector connector;
    private final Database database;

    public ExampleStore() throws SQLException
    {
        connector = new DatabaseConnector();
        database = new Database("testdb", "test");
    }

    public static void main(String[] args)
    {
        try
        {
            new ExampleStore().export();
        }
        catch (Exception ex)
        {
            Logger.getLogger(ExampleStore.class.getName()).log(Level.SEVERE,
                    null, ex);
        }
    }

    private void export() throws IOException, ResourceException
    {
        new UpdateJob(database, UpdateJob.Method.Replace) {
            @Override
            protected void updateItems() throws IOException
            {
                try
                {
                    for(final Integer customer : connector.getCustomerIDs())
                    {
                        updateItem("customer" + customer, new Updater() {
                            @Override
                            public void update(Item item)
                            {
                                try
                                {
                                    item.addTag("customer");
                                    List<Integer> purchases =
                                            connector.getProductIDsForCustomerID(customer);
                                    for(Integer product : purchases)
                                    {
                                        item.linkTo("product" + product);
                                    }
                                }
                                catch (SQLException ex)
                                {
                                    Logger.getLogger(ExampleStore.class.getName()).log(
                                            Level.SEVERE, null, ex);
                                }
                            }
                        });
                    }
                    for(final Integer product : connector.getProductIDs())
                    {
                        updateItem("product" + product, new Updater() {
                            @Override
                            public void update(Item item)
                            {
                                item.addTag("product");
                            }
                        });
                    }
                }
                catch (SQLException ex)
                {
                    Logger.getLogger(ExampleStore.class.getName()).log(
                            Level.SEVERE, null, ex);
                }
            }
        }.run();

        new UpdateJob(database, UpdateJob.Method.Update) {
            @Override
            protected void updateItems() throws IOException
            {
                updateItem("customer0", new Updater() {
                    @Override
                    public void update(Item item)
                    {
                        item.addTag("partner");
                        item.removeTag("customer");
                    }
                });
            }
        }.run();
    }
}
