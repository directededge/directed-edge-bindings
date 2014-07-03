using System;

namespace DirectedEdge
{
    public class Link
    {
        public string Target { get; set; }
        public string Type { get; set; }
        public int Weight { get; set; }

        public Link(string target, string type = null, int weight = 0)
        {
            Target = target;
            Type = type;
            Weight = weight;
        }

        public Link(string target, int weight) : this(target, null, weight)
        {

        }
    }
}