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
        Database database = new Database("testdb", "test");
        database.importFromFile("../testdb.xml");
        updater = new Updater(database);
    }

    @After
    public void tearDown()
    {

    }

    @Test
    public void update()
    {
        Item item = new Item(updater.getDatabase(), "test1");
        item.addTag("test2");
        item.setProperty("test3", "test4");
        updater.export(item);
        updater.finish();

        item = new Item(updater.getDatabase(), "test1");
        assertTrue(item.getTags().contains("test2"));
        assertEquals("test4", item.getProperty("test3"));
    }
}