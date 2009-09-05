import com.directededge.Exporter;
import com.directededge.Item;
import java.io.File;
import java.io.IOException;
import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import org.junit.After;
import org.junit.AfterClass;
import org.junit.Before;
import org.junit.BeforeClass;
import org.junit.Test;
import org.w3c.dom.Document;
import org.w3c.dom.NodeList;
import static org.junit.Assert.*;
import org.xml.sax.SAXException;

public class ExporterTest
{
    private Exporter exporter;

    public ExporterTest()
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
    public void setUp()
    {
        exporter = new Exporter("test.xml");
    }

    @After
    public void tearDown()
    {

    }


    @Test
    public void exportFile() throws ParserConfigurationException, SAXException, IOException
    {
        Item first = new Item(exporter.getDatabase(), "first");
        Item second = new Item(exporter.getDatabase(), "second");
        first.linkTo(second);
        first.addTag("tag1");
        second.addTag("tag2");
        first.setProperty("testkey", "testvalue");
        exporter.export(first);
        exporter.export(second);
        exporter.finish();

        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        DocumentBuilder builder = factory.newDocumentBuilder();
        Document doc = builder.parse(new File("test.xml"));

        NodeList itemNodes = doc.getElementsByTagName("item");

        assertEquals(itemNodes.getLength(), 2);

        assertEquals(itemNodes.item(0).getAttributes().getNamedItem("id").getTextContent(),
                     "first");
        assertEquals(itemNodes.item(1).getAttributes().getNamedItem("id").getTextContent(),
                     "second");
    }

}