Debug = {};
Debug.debug = function(message)
{
	alert(message);
}


/********************************************************************************
 * HTTP code from From the book JavaScript: The Definitive Guide, 5th Edition
 ********************************************************************************/

HTTP = {};

HTTP.factories = [
    function() { return new XMLHttpRequest(); },
    function() { return new ActiveXObject("Msxml2.XMLHTTP"); },
    function() { return new ActiveXObject("Microsoft.XMLHTTP"); }
 ];

HTTP.factory = null;

HTTP.newRequest = function()
{
    if (HTTP.factory != null)
    {
    return HTTP.factory();
    }

    for(var i = 0; i < HTTP.factories.length; i++)
    {
        try
    {
            var factory = HTTP.factories[i];
            var request = factory();
            if(request != null)
        {
                HTTP.factory = factory;
                return request;
            }
        }
        catch(e)
    {
            continue;
        }
    }

    // If we get here, none of the factory candidates succeeded,
    // so throw an exception now and for all future calls.

    HTTP.factory = function()
    {
        throw new Error("XMLHttpRequest not supported");
    }

    HTTP.factory(); // Throw an error
}

HTTP.getXML = function(url, cb, parameter)
{
    var request = HTTP.newRequest();

    request.onreadystatechange = function()
    {
        if(request.readyState == 4 && request.status == 200)
        {
            cb.callback.call(cb.obj, request.responseXML, parameter);
        }
    }

    request.open("GET", url);
    request.send(null);
}

HTTP.postXML = function(url, cb, data)
{
    var request = HTTP.newRequest();

    

    request.onreadystatechange = function()
    {
        Debug.debug("postXML: state: " + request.readyState + " status: " + request.status);
        if(request.readyState == 4 && request.status == 200)
        {
            cb.callback.call(cb.obj);
        }
    }

    request.open("PUT", url);
    request.setRequestHeader("Content-Type", "text/xml");
    request.send(data);
}

function Resource(base, hasQuestionMark)
{
	this.base = base;
	if (arguments.length > 1)
	{
		this.hasQuestionMark = hasQuestionMark;
	}
	else
	{
		this.hasQuestionMark = false;
	}
}

Resource.prototype.addResource = function(r)
{
	return new Resource(this.base + "/" + r);
}

Resource.prototype.addKeyValuePair = function(k, v)
{
	if(this.hasQuestionMark)
	{
		var rb = new Resource(this.base + "&" + k + "=" + v, true);
		return rb;
	}

	var rb = new Resource(this.base + "?" + k + "=" + v, true);
	return rb;
}

Resource.prototype.url = function()
{
	return this.base;
}

function Database() {
    this.name = "";
    this.password = "";
    this.host = "webservice.directededge.com";
    this.protocol = "http";
    this.resource = "/api/v1/";
    this.base = new Resource();

    this.initialize = function(name, password, host, protocol) {
        this.name = name;
        this.password = password;
        this.host = host;

        this.base = new Resource(protocol + "://" + name + ":" + password + "@" + host + this.resource + name);
    }
}

function Item(database, id)
{
    this.id = id;
    this.database = database;
    this.resource = database.base.addResource(id);

    //item data
    this.tags = new Array();
    this.links = new Array();
    this.properties = new Array();

    //handle callbacks for functions waiting for data read
    this.readCBs = new Array();
    this.cached = false;
}

Item.prototype.readHandler = function(text, cb)
{
    Debug.debug("readHandler");

    var rlinks = text.getElementsByTagName("link");
    for(var i=0; i < rlinks.length; i++)
    {
        this.links.push(new Item(this.database, rlinks.item(i).childNodes[0].nodeValue));
    }

    var rtags = text.getElementsByTagName("tag");
    for(var i=0; i < rtags.length; i++)
    {
        this.tags.push(rtags.item(i).childNodes[0].nodeValue);
    }

    var rproperties = text.getElementsByTagName("property");
    for(var i=0; i < rproperties.length; i++)
    {
        this.properties[rproperties.item(i).attributes[0].value] = rproperties.item(i).childNodes[0].nodeValue;
    }

    this.cached = true;

    while(this.readCBs.length > 0)
    {
	var cc = this.readCBs.shift();
    	cc.call(this);
    }
}

Item.prototype.relatedHandler = function(text, callback)
{
	var related = new Array();
	var ritems = text.getElementsByTagName("related");

	for(var i=0; i < ritems.length; i++)
	{
		related.push(new Item(this.database, ritems.item(i).childNodes[0].nodeValue));
	}

	callback(related);
}

Item.prototype.recommendedItems = function(callback)
{
    getR = HTTP.newRequest();
    HTTP.getXML(this.resource.addResource("recommended").url(), {obj: this, callback: this.relatedHandler}, callback);
}

Item.prototype.relatedItems = function(callback, excludeLinked, maxResults, tags)
{
	var res = this.resource.addResource("related");
	if(arguments.length > 1)
	{
		res = res.addKeyValuePair("excludeLinked", excludeLinked).addKeyValuePair("maxResults", maxResults);
		if(typeof(tags) == "object")
		{
			res = res.addKeyValuePair("tags", tags.join(","));
		}
		else
		{
			var tagsA = new Array();
			var t = arguments.length - 3;
			for(var i=3; i < arguments.length; i++)
			{
				tagsA.push(arguments[i]);
			}
			
			res = res.addKeyValuePair("tags", tags.join(","));
		}
		Debug.debug("relatedItems tags type: " + typeof(tags));
	}

	Debug.debug("relatedItems: query: " + res.url());

    getR = HTTP.newRequest();
    HTTP.getXML(res.url(), {obj: this, callback: this.relatedHandler}, callback);
}

Item.prototype.read = function(callback)
{
    this.readCBs.push(callback);

    //don't start another query while another is still on the run
    if(this.readCBs.length > 1)
    {
        return;
    }

    getR = HTTP.newRequest();
    HTTP.getXML(this.resource.url(), {obj: this, callback: this.readHandler}, callback);
}

Item.prototype.getLinks = function(callback)
{
    Debug.debug("getLinks (cached: " + this.cached + ")");

    if(this.cached)
    {
        callback(this.links);
    }
    else
    {
        this.read(function() { callback(this.links); });
    }
}

Item.prototype.getTags = function(callback)
{
    Debug.debug("getTag (cached: " + this.cached + ")");

    if (this.cached)
    {
        callback(this.tags);
    }
    else
    {
        this.read(function() { callback(this.tags); });
    }
}

Item.prototype.addTag = function(tag)
{
    Debug.debug("addTag " + tag);
    this.tags.push(tag);
}

Item.prototype.setProperty = function(key, value)
{
    this.properties[key] = value;
}

/**
 * callback also here?!
 */
Item.prototype.getProperty = function(key)
{
    return this.properties[key];
}

Item.prototype.getProperties = function(callback)
{
    if (this.cached)
    {
        callback(this.properties);
    }
    else
    {
        this.read(function() { callback(this.properties); });
    }
}

Item.prototype.save = function(callback)
{
    Debug.debug("save");
    HTTP.postXML(this.resource.url(), {obj: this, callback: callback}, this.toXML());
}

Item.prototype.toXML = function()
{
/*
    //var xmlstring = '<?xml version="1.0" encoding="UTF-8"?>';
    var xmlstring = '';
    var xmlobject = (new DOMParser()).parseFromString(xmlstring, "text/xml");
    var de = xmlobject.createElement("directededge");
    de.setAttribute("version", "1.0");
    //xmlobject.appendChild(de);

    var item = xmlobject.createElement("item");
    item.setAttribute("id", this.id);

    for(var i=0; i < this.links.length; i++)
    {
        var li = xmlobject.createElement("link");
        li.appendChild(xmlobject.createTextNode(this.links[i]));
        item.appendChild(li);
    }

    de.appendChild(item);
    xmlobject.appendChild(de);
*/

    var xmlstring = '<?xml version="1.0" encoding="UTF-8"?>\n';
    xmlstring += '<directededge version="1.0">\n';
    xmlstring += '<item id="' + this.id + '">\n';

    for(var i=0; i < this.links.length; i++)
    {
        xmlstring += '<link>'+this.links[i].id+'</link>\n';
    }
 
    for(var i=0; i < this.tags.length; i++)
    {
        xmlstring += '<tag>'+this.tags[i]+'</tag>\n';
    }

    for(key in this.properties)
    {
        xmlstring += '<property name="' + key + '">' + this.properties[key] + '</property>\n';
    }
 
    xmlstring += '</item>\n</directededge>\n\n';
    return xmlstring;
}

