using System;

namespace DirectedEdge
{
    public class Database
    {
        private Resource resource;
        public Resource Resource
        {
            get { return resource; }
        }

        public Database(string user, string password)
        {
            var builder = new UriBuilder();
            builder.Scheme = "http";
            var host = Environment.GetEnvironmentVariable("DIRECTEDEDGE_HOST");
            builder.Host = host == null ? "webservices.directededge.com" : host;
            builder.Path = "/api/v1/" + user + "/";
            builder.UserName = user;
            builder.Password = password;
            resource = new Resource(builder.Uri);
        }
    }
}

