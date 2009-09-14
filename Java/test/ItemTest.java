import com.directededge.Database;
import com.directededge.Database.ResourceException;
import com.directededge.Item;
import java.util.HashSet;
import org.junit.After;
import org.junit.AfterClass;
import org.junit.Before;
import org.junit.BeforeClass;
import org.junit.Test;
import static org.junit.Assert.*;

public class ItemTest
{
    private Database database;

    public ItemTest()
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
        database = new Database("testdb", "test");
        database.importFromFile("../testdb.xml");
    }

    @After
    public void tearDown()
    {

    }

    @Test
    public void create()
    {
        Item item = new Item(database, "test");
        item.linkTo("customer0");
        item.linkTo("customer1");
        item.save();

        item = new Item(database, "test");
        assertTrue(item.getLinks().containsKey("customer0"));
        assertTrue(item.getLinks().containsKey("customer1"));
    }

    @Test
    public void unweightedLinks()
    {
        Item customer0 = new Item(database, "customer0");
        customer0.linkTo("customer1");
        customer0.save();

        customer0 = new Item(database, "customer0");
        assertTrue(customer0.getLinks().containsKey("customer1"));

        customer0.unlinkFrom("customer1");
        customer0.save();
        customer0 = new Item(database, "customer0");
        assertFalse(customer0.getLinks().containsKey("customer1"));
    }

    @Test
    public void weightedLinks()
    {
        Item customer0 = new Item(database, "customer0");
        customer0.linkTo("product7", 5);
        customer0.save();

        customer0 = new Item(database, "customer0");
        assertTrue(customer0.getLinks().containsKey("product7"));
        assertEquals((int) customer0.getLinks().get("product7"), 5);
        assertEquals(customer0.weightFor("product7"), 5);

        customer0.unlinkFrom("product7");
        customer0.save();
        customer0 = new Item(database, "customer0");
        assertFalse(customer0.getLinks().containsKey("product7"));
    }

    @Test
    public void tags()
    {
        Item customer = new Item(database, "customer0");
        assertTrue(customer.getTags().contains("customer"));
        customer.addTag("test");
        assertTrue(customer.getTags().contains("test"));
        customer.save();
        customer = new Item(database, "customer0");
        assertTrue(customer.getTags().contains("test"));
        customer.removeTag("test");
        assertFalse(customer.getTags().contains("test"));
        customer.save();
        customer = new Item(database, "customer0");
        assertFalse(customer.getTags().contains("test"));
    }

    @Test
    public void properties()
    {
        Item customer = new Item(database, "customer0");
        customer.setProperty("test", "first");
        System.out.println("properties: " + customer.getProperties().size());
        assertEquals("first", customer.getProperty("test"));
        customer.setProperty("test", "second");
        assertEquals("second", customer.getProperty("test"));
        customer.save();
        customer = new Item(database, "customer0");
        assertEquals(1, customer.getProperties().size());
        assertEquals("second", customer.getProperty("test"));
        customer.setProperty("test", "third");
        customer.save();
        assertEquals("third", customer.getProperty("test"));
        customer = new Item(database, "customer0");
        assertEquals("third", customer.getProperty("test"));
        customer.clearProperty("test");
        assertEquals(0, customer.getProperties().size());
        customer.save();
        customer = new Item(database, "customer0");
        assertEquals(0, customer.getProperties().size());
    }

    @Test
    public void recommended()
    {
        HashSet<String> tags = new HashSet<String>();
        tags.add("product");

        Item customer = new Item(database, "customer0");
        assertEquals(20, customer.getRecommended().size());
        assertEquals(20, customer.getRecommended(tags).size());
        assertEquals(5, customer.getRecommended(tags, 5).size());
    }

    @Test
    public void related()
    {
        HashSet<String> tags = new HashSet<String>();
        tags.add("product");

        Item customer = new Item(database, "product0");
        assertEquals(20, customer.getRelated().size());
        assertEquals(20, customer.getRelated(tags).size());
        assertEquals(5, customer.getRelated(tags, 5).size());
    }
}