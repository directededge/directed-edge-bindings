using System;

namespace DirectedEdge
{
    public class Item
    {
        private Database database;
        public Database Database
        {
            get { return database; }
        }

        private string id;
        public string Id
        {
            get { return id; }
        }

        private Resource resource;
        public Resource Resource
        {
            get { return resource; }
        }

        public Item(Database database, string id)
        {
            this.id = id;
            this.database = database;
            resource = database.Resource.Child(id);
        }
    }
}