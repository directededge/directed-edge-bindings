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
        public List<Link> Links { get; private set; }

        public Item(Database database, string id)
        {
            Database = database;
            Id = id;
            Resource = database.Resource.Child(id);
            Links = new List<Link>();
        }

        public void Load()
        {
            var doc = new XmlDocument();
            doc.LoadXml(Resource.Get());
            foreach(XmlNode node in doc.GetElementsByTagName("link"))
            {
                XmlAttribute weight = node.Attributes["weight"];
                XmlAttribute type = node.Attributes["type"];
                Links.Add(new Link(node.InnerText,
                        type == null ? null : node.InnerText,
                        weight == null ? 0 : Convert.ToInt32(weight.Value)));
            }
        }
    }
}