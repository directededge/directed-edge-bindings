using System;
using System.Xml;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Runtime.CompilerServices;

namespace DirectedEdge
{
    public class Item
    {
        public Database Database { get; private set; }
        public string Id { get; private set; }
        public Resource Resource { get; private set; }

        public ListProxy<Link> Links { get; private set; }
        public ListProxy<string> Tags { get; private set; }
        public Dictionary<string, string> Properties { get; private set; }

        [IndexerName("IndexedItem")]
        public string this[string property]
        {
            get { return Properties[property]; }
            set { Properties[property] = value; }
        }

        public Item(Database database, string id)
        {
            Database = database;
            Id = id;
            Resource = database.Resource[id];
            Links = new ListProxy<Link>(Load);
            Tags = new ListProxy<string>(Load);
            Properties = new Dictionary<string, string>();
        }

        public void Load()
        {
            var doc = new XmlDocument();
            doc.LoadXml(Resource.Get());

            var links = new List<Link>();

            foreach(XmlNode node in doc.GetElementsByTagName("link"))
            {
                var weight = node.Attributes["weight"];
                var type = node.Attributes["type"];
                links.Add(new Link(node.InnerText,
                        type == null ? null : node.InnerText,
                        weight == null ? 0 : Convert.ToInt32(weight.Value)));
            }

            Links.Set(links);

            var tags = new List<string>();

            foreach(XmlNode node in doc.GetElementsByTagName("tag"))
            {
                tags.Add(node.InnerText);
            }

            Tags.Set(tags);

            foreach(XmlNode node in doc.GetElementsByTagName("property"))
            {
                var name = node.Attributes["name"];
                if(node != null)
                {
                    Properties.Add(name.Value, node.InnerText);
                }
            }
        }

        public void Save()
        {
            Resource.Put(ToXml());
        }

        public string ToXml()
        {
            var doc = new XmlDocument();
            var root = CreateElement(doc, doc, "directededge", e => e.SetAttribute("version", "0.1"));
            var item = CreateElement(doc, root, "item", e => e.SetAttribute("id", Id));

            foreach(var tag in Tags)
            {
                CreateElement(doc, item, "tag", e => e.InnerText = tag);
            }

            foreach(var link in Links)
            {
                CreateElement(doc, item, "link", e => {
                    if(link.Type != null)
                    {
                        e.SetAttribute("type", link.Type);
                    }
                    if(link.Weight != 0)
                    {
                        e.SetAttribute("weight", link.Weight.ToString());
                    }
                    e.InnerText = link.Target;
                });
            }

            foreach(var property in Properties)
            {
                CreateElement(doc, item, "property", e => {
                    e.SetAttribute("name", property.Key);
                    e.InnerText = property.Value;
                });
            }

            return doc.OuterXml;
        }

        private XmlElement CreateElement(XmlDocument doc, XmlNode parent, string name,
            System.Action<XmlElement> builder)
        {
            var e = (XmlElement) parent.AppendChild(doc.CreateElement(name));
            builder.Invoke(e);
            return e;
        }
    }
}