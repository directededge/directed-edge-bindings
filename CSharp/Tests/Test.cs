using NUnit.Framework;
using System;

namespace Tests
{
    [TestFixture]
    public class Test
    {
        [Test]
        public void TestCase()
        {
            var database = new DirectedEdge.Database("testdb", "test");
            var customer = new DirectedEdge.Item(database, "customer1");
            customer.Load();
            Assert.IsTrue(customer.Links.Count == 15);
        }
    }
}

