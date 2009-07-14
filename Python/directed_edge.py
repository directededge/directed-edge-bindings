import os
import urllib2
import httplib2

class Resource:
    def __init__(self, base_url, user=None, password=None):
        self.base_url = base_url
        self.http = httplib2.Http()
        if user:
            self.http.add_credentials(user, password)

    def path(self, sub=""):
        return self.base_url + "/" + urllib2.quote(sub)

#    def get(sub=""):

class Database:
    def __init__(self, name, password="", protocol="http"):
        if 'DIRECTEDEDGE_HOST' in os.environ.keys():
            host = os.environ["DIRECTEDEDGE_HOST"]
        else:
            host = "webservices.directededge.com"
        self.name = name
        self.resource = Resource("http://%s/api/v1/%s" % (host, name), name, password)


