using System;
using RestSharp;

namespace DirectedEdge
{
	public class Resource
    {
        private Uri uri;
		private RestClient client;

		public Resource(Uri uri)
		{
            this.uri = uri;
			client = new RestClient();
            client.BaseUrl = uri.ToString();
            var auth = uri.UserInfo.Split(':');
            client.Authenticator = new HttpBasicAuthenticator(auth[0], auth[1]);
		}

        public Resource(String destination) : this(new Uri(destination))
		{

		}

		public string Get()
		{
            return client.Execute(new RestRequest()).Content;
		}

		public Resource Child(string path)
		{
            return new Resource(new Uri(uri, path));
		}
	}
}