using NUnit.Framework;
using System;
using System.IO;
using System.Text.RegularExpressions;

namespace Tests
{
    [TestFixture]
    public class Test
    {
        private DirectedEdge.Database database;

        [SetUp]
        public void Init()
        {
            database = new DirectedEdge.Database("testdb", "test");
            database.Import(TestDbFile());
        }

        [Test]
        public void TestCase()
        {
            var customer = new DirectedEdge.Item(database, "customer1");
            customer.Load();
            Assert.IsTrue(customer.Links.Count == 15);
            Assert.Contains("customer", customer.Tags);
        }

        private string TestDbFile()
        {
            string dir = Directory.GetCurrentDirectory();
            dir = new Regex("DirectedEdge\\/Bindings.*").Replace(dir, "DirectedEdge/Bindings");
            return Path.Combine(dir, "testdb.xml");
        }
    }
}

