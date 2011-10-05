import java.io.FileInputStream;
import com.directededge.Database;
import com.directededge.Database.ResourceException;
import com.directededge.Item;
import java.io.FileNotFoundException;
import org.junit.After;
import org.junit.AfterClass;
import org.junit.Before;
import org.junit.BeforeClass;
import org.junit.Test;
import static org.junit.Assert.*;

public class DatabaseTest
{
    public DatabaseTest()
    {

    }

    @BeforeClass
    public static void setUpClass() throws Exception
    {

    }

    @AfterClass
    public static void tearDownClass() throws Exception
    {

    }

    @Before
    public void setUp() throws ResourceException
    {

    }

    @After
    public void tearDown()
    {

    }

    @Test
    public void fileImportTest() throws ResourceException
    {
        Database database = new Database("testdb", "test");
        database.importFromFile("../testdb.xml");
        importTest(database);
    }

    @Test
    public void streamImportTest() throws ResourceException, FileNotFoundException
    {
        Database database = new Database("testdb", "test");
        database.importFromStream(new FileInputStream("../testdb.xml"));
        importTest(database);
    }

    private void importTest(Database database)
    {
        Item customer0 = new Item(database, "customer0");
        assertEquals(customer0.getLinks("").size(), 10);

        Item product49 = new Item(database, "product49");
        assertEquals(product49.getLinks("").size(), 0);
        assertTrue(product49.getTags().contains("product"));
        assertFalse(product49.getTags().contains("user"));
    }
}