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
            var resource = new DirectedEdge.Resource("http://testdb:test@localhost/api/v1/testdb");
            Assert.True(resource.Get().Length > 0);

            var database = new DirectedEdge.Database("testdb", "test");
            var customer = new DirectedEdge.Item(database, "customer1");
            Console.WriteLine(customer.Resource.Get());
            // Assert.True(database.Resource.Get().Length > 0);
        }
    }
}

