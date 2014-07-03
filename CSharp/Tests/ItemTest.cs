using NUnit.Framework;
using System;
using System.IO;
using System.Collections;
using System.Text.RegularExpressions;

namespace Tests
{
    [TestFixture]
    public class ItemTest
    {
        private DirectedEdge.Database database;
        private DirectedEdge.Item customer;
        private DirectedEdge.Item product;

        [SetUp]
        public void Init()
        {
            database = new DirectedEdge.Database("testdb", "test");
            database.Import(TestDbFile());
            customer = new DirectedEdge.Item(database, "customer1");
            product = new DirectedEdge.Item(database, "product1");

            // These should be removed later once auto-loading is done

            customer.Load();
            product.Load();
        }

        [Test]
        public void TestLinks()
        {
            Assert.IsTrue(customer.Links.Count == 15);
        }

        [Test]
        public void TestTags()
        {
            Assert.AreEqual(new ArrayList(new [] { "customer" }), customer.Tags);
            Assert.AreEqual(new ArrayList(new [] { "product" }), product.Tags);
        }

        [Test]
        public void TestProperties()
        {
            customer.Properties.Add("age", "42");
            customer.Save();
            customer = new DirectedEdge.Item(database, "customer1");
            customer.Load();
            Assert.AreEqual("42", customer.Properties["age"]);
        }

        private string TestDbFile()
        {
            string dir = Directory.GetCurrentDirectory();
            dir = new Regex("DirectedEdge\\/Bindings.*").Replace(dir, "DirectedEdge/Bindings");
            return Path.Combine(dir, "testdb.xml");
        }
    }
}

