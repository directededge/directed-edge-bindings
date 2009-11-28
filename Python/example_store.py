#!/usr/bin/python

from sqlalchemy import Column, Integer, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

from directed_edge import Exporter, Item, Database

Base = declarative_base()

class Customer(Base):
    __tablename__ = "customers"
    id = Column(Integer, primary_key=True)

class Product(Base):
    __tablename__ = "products"
    id = Column(Integer, primary_key=True)

class Purchase(Base):
    __tablename__ = "purchases"
    customer = Column(Integer, primary_key=True)
    product = Column(Integer, primary_key=True)

class ExampleStore(object):
    def __init__(self):
        self.database = Database("examplestore", "password")
        engine = create_engine("mysql://examplestore:password@localhost/examplestore")
        Session = sessionmaker(bind=engine)
        self.session = Session()

    def export_from_mysql(self):
        exporter = Exporter("examplestore.xml")

        for product in self.session.query(Product):
            item = Item(exporter.database, "product%s" % product.id)
            item.add_tag("product")
            exporter.export(item)
            
        for customer in self.session.query(Customer):
            item = Item(exporter.database, "customer%s" % customer.id)
            item.add_tag("customer")
            for purchase in self.session.query(Purchase).filter_by(customer=customer.id):
                item.link_to("product%s" % purchase.product)
            exporter.export(item)

        exporter.finish()

    def import_to_directededge(self):
        self.database.import_from_file("examplestore.xml")

    def create_customer(self, id):
        item = Item(self.database, "customer%s" % id)
        item.add_tag("customer")
        item.save()

    def create_product(self, id):
        item = Item(self.database, "product%s" % id)
        item.add_tag("product")
        item.save()

    def add_purchase(self, customer_id, product_id):
        item = Item(self.database, "customer%s" % customer_id)
        item.link_to("product%s" % product_id)
        item.save()

    def related_products(self, product_id):
        item = Item(self.database, "product%s" % product_id)
        return [related.replace("product", "") for related in item.related(["product"])]

    def personalized_recommendations(self, customer_id):
        item = Item(self.database, "customer%s" % customer_id)
        return [related.replace("product", "") for related in item.recommended(["product"])]

        
store = ExampleStore()
store.export_from_mysql()
store.import_to_directededge()

store.create_customer(1000)
store.create_product(1000)
store.add_purchase(1000, 1000)

print store.related_products(2)
print store.personalized_recommendations(2)
