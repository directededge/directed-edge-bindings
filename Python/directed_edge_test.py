import directed_edge
import unittest
import os
import socket
import time

class QueryTest(unittest.TestCase):
    def setUp(self):
        self.database = directed_edge.Database(os.environ["DIRECTEDEDGE_TEST_DB"],
                                               os.environ["DIRECTEDEDGE_TEST_PASS"])
        self.database.import_from_file("../testdb.xml")
        self.customer = directed_edge.Item(self.database, "customer1")
        self.product = directed_edge.Item(self.database, "product1")

    def testLinks(self):
        self.assert_(len(self.customer.links()) == 15)
        self.assert_("product4" in self.customer.links())
        customer3 = directed_edge.Item(self.database, "customer3")
        self.customer.link_to(customer3, 10)
        self.assert_("customer3" in self.customer.links())
        self.assert_(self.customer.weight_for("customer3") == 10)
        self.assertRaises(Exception, self.customer.link_to, self.product, -1)
        self.assertRaises(Exception, self.customer.link_to, self.product, 11)

    def testTags(self):
        self.assert_(len(self.customer.tags) == 1)
        self.customer.add_tag("foo")
        self.assert_("foo" in self.customer.tags)

    def testRelated(self):
        self.assert_(len(self.product.related([], maxResults=5)) == 5)
        self.assert_(self.product.related([], popularity=0) !=
                     self.product.related([], popularity=1))
        self.assert_("product21" in self.product.related(["product"]))

    def testGroupRelated(self):
        self.assert_(len(self.database.group_related(["product1", "product2"], ["product"])) > 0)
        self.assert_(self.database.group_related(["product1"]) ==
                     self.product.related())

    def testProperties(self):
        self.customer["foo"] = "bar"
        self.assert_(self.customer.properties["foo"] == "bar")
        self.customer["baz"] = "quux"
        self.assert_(self.customer["baz"] == "quux")
        self.assert_(self.customer.get_property("baz") == "quux")
        self.customer.clear_property("baz")
        self.assert_(not self.customer.has_property("baz"))
        self.assert_(not self.customer.get_property("quux"))

    def testSave(self):
        item = lambda name: directed_edge.Item(self.database, name)

        foo = item("Foo")
        foo.add_tag("blah")
        foo.save()
        foo = item("Foo")
        self.assert_("blah" in foo.tags)
        foo = item("Foo")
        foo.remove_tag("blah")
        foo.save()
        foo = item("Foo")
        self.assert_("blah" not in foo.tags)

        foo = item("Foo")
        foo["baz"] = "quux"
        foo.save()
        foo = item("Foo")
        self.assert_(foo["baz"] == "quux")
        foo = item("Foo")
        foo["baz"] = "bar"
        foo.save()
        foo = item("Foo")
        self.assert_(foo["baz"] == "bar")
        foo.clear_property("baz")
        foo.save()
        foo = item("Foo")
        self.assert_("baz" not in foo.properties)        

        bar = item("Bar")
        bar.link_to(foo, 10)
        bar.save()
        bar = item("Bar")
        self.assert_(bar.links()["Foo"] == 10)
        bar.unlink_from(foo)
        bar.save()
        bar = item("Bar")
        self.assert_("Foo" not in bar.links())

    def testDestroy(self):
        customer = directed_edge.Item(self.database, "customer1")
        self.assert_(len(customer.links()) > 0)
        customer.destroy()
        customer = directed_edge.Item(self.database, "customer1")
        self.assert_(len(customer.links()) == 0)

    def testExport(self):
        exporter = directed_edge.Exporter("exported.xml")

        foo = directed_edge.Item(exporter.database, "Foo")
        foo.add_tag("blah")
        foo["baz"] = "quux"
        exporter.export(foo)

        bar = directed_edge.Item(exporter.database, "Bar")
        bar.link_to(foo, 5, "magic")
        exporter.export(bar)

        exporter.finish()

    def testAdd(self):
        exporter = directed_edge.Exporter(self.database)
        foo = directed_edge.Item(exporter.database, "Foo")
        foo.add_tag("blah")
        foo["baz"] = "quux"
        exporter.export(foo)
        exporter.finish()

        foo = directed_edge.Item(exporter.database, "Foo")
        self.assert_(foo["baz"] == "quux")

    def testNonexistant(self):
        item = directed_edge.Item(self.database, "Asdf")
        self.assert_(not item.tags)

    def testLinkTypes(self):
        foo = directed_edge.Item(self.database, "Foo")
        bar = directed_edge.Item(self.database, "Bar")

        foo.link_to(bar, 0, "thinger")

        bar.save()
        foo.save()

        foo = directed_edge.Item(self.database, "Foo")
        bar = directed_edge.Item(self.database, "Bar")

        self.assert_("thinger" in foo.link_types)

    def testCharacters(self):
        for id in [ ";@%&!", "foo/bar" ]:
            item = directed_edge.Item(self.database, id)
            item["foo"] = "bar"
            item.save()
            item = directed_edge.Item(self.database, id)
            self.assert_(item["foo"] == "bar")

    def testTimeout(self):
        if not "TEST_TIMEOUT" in os.environ:
            return

        database = directed_edge.Database("dummy", "dummy", "http",
                                          timeout = 5, host = "localhost:4567")

        start = time.time()
        timed_out = False
        timeout = 10
        item = directed_edge.Item(database, "dummy")
        try:
            item.tags()
        except socket.timeout:
            timed_out = True
            self.assert_(time.time() - start < timeout + 1)
        self.assert_(timed_out)

if __name__ == '__main__':
    unittest.main()
