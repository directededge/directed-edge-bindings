import com.directededge.Database;
import com.directededge.Database.ResourceException;
import com.directededge.Item;
import com.directededge.Updater;
import java.io.File;
import org.junit.After;
import org.junit.AfterClass;
import org.junit.Before;
import org.junit.BeforeClass;
import org.junit.Test;
import static org.junit.Assert.*;

public class UpdaterTest
{
    private Updater updater;
    private Database database;

    public UpdaterTest()
    {

    }

    @BeforeClass
    public static void setUpClass() throws Exception
    {

    }

    @AfterClass
    public static void tearDownClass() throws Exception
    {
        new File("test.xml").delete();
    }

    @Before
    public void setUp() throws ResourceException
    {
        database = new Database("testdb", "test");
        database.importFromFile("../testdb.xml");
    }

    @After
    public void tearDown()
    {

    }

    @Test
    public void add()
    {
        updater = new Updater(database);
        Item item = new Item(updater.getDatabase(), "test1");
        item.addTag("test2");
        item.setProperty("test3", "test4");
        updater.export(item);
        updater.finish();

        item = new Item(updater.getDatabase(), "test1");
        assertTrue(item.getTags().contains("test2"));
        assertEquals("test4", item.getProperty("test3"));
    }

    @Test
    public void subtract()
    {
        updater = new Updater(database, Updater.Method.Subtract);
        Item item = new Item(updater.getDatabase(), "customer1");
        assertTrue(item.getTags().contains("customer"));

        item = new Item(updater.getDatabase(), "customer1");
        item.removeTag("customer");
        updater.export(item);
        updater.finish();

        item = new Item(updater.getDatabase(), "customer1");
        assertFalse(item.getTags().contains("customer"));
        assertTrue(item.getLinks().size() > 0);
    }
}