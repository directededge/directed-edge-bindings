using System;
using System.Xml;
using System.Collections.Generic;

namespace DirectedEdge
{
    public class Item
    {
        public Database Database { get; private set; }
        public string Id { get; private set; }
        public Resource Resource { get; private set; }
        public Dictionary<string, int> Links { get; private set; }

        public Item(Database database, string id)
        {
            Database = database;
            Id = id;
            Resource = database.Resource.Child(id);
            Links =  new Dictionary<string, int>();
        }

        public void Load()
        {
            var doc = new XmlDocument();
            doc.LoadXml(Resource.Get());
            foreach(XmlNode node in doc.GetElementsByTagName("link"))
            {
                XmlAttribute weight = node.Attributes["weight"];
                Links.Add(node.InnerText, weight == null ? 0 : Convert.ToInt32(weight.Value));
            }
        }
    }
}