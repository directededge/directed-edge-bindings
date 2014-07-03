using System;
using System.Collections;
using System.Collections.Generic;

namespace DirectedEdge
{
    public class ListProxy<T> : IList<T>, ICollection<T>, ICollection
    {
        private bool isCached;
        private List<T> cached;
        private List<T> add;
        private List<T> remove;

        private Action loader;

        public ListProxy(Action loader)
        {
            this.loader = loader;
            Reset();
        }

        public bool IsReadOnly
        {
            get { return false; }
        }

        public bool IsFixedSize
        {
            get { return false; }
        }

        public bool IsSynchronized
        {
            get { return false; }
        }

        public object SyncRoot
        {
            get { return cached; }
        }

        public int Count
        {
            get { return Load(() => cached.Count ); }
        }

        public T this[int i]
        {
            get
            {
                return Load(() => cached[i]);
            }
            set
            {
                Load(() => cached[i] = value);
            }
        }

        public void Add(T item)
        {
            if(isCached)
            {
                cached.Add(item);
            }
            else
            {
                remove.Remove(item);
                add.Add(item);
            }
        }

        public int IndexOf(T item)
        {
            return Load(() => cached.IndexOf(item));
        }

        public void Insert(int i, T o)
        {
            Load(() => cached.Insert(i, o));
        }

        public void RemoveAt(int i)
        {
            Load(() => cached.RemoveAt(i));
        }

        public void Clear()
        {
            Reset();
            isCached = true;
        }

        public bool Contains(T item)
        {
            return Load(() => cached.Contains(item));
        }

        public void CopyTo(T[] array, int i)
        {
            Load(() => cached.CopyTo(array, i));
        }

        public void CopyTo(Array array, int i)
        {
            Load(() => cached.CopyTo((T[]) array, i));
        }

        public bool Remove(T item)
        {
            if(isCached)
            {
                return cached.Remove(item);
            }
            else
            {
                remove.Add(item);
                add.Remove(item);
                return true;
            }
        }

        IEnumerator<T> IEnumerable<T>.GetEnumerator()
        {
            return Load(() => cached.GetEnumerator());
        }

        IEnumerator IEnumerable.GetEnumerator()
        {
            return Load(() => cached.GetEnumerator());
        }

        public void Reset()
        {
            isCached = false;
            cached = new List<T>();
            add = new List<T>();
            remove = new List<T>();
        }

        public void Set(List<T> values)
        {
            isCached = true;
            cached = values;

            foreach(var item in add)
            {
                Add(item);
            }

            foreach(var item in remove)
            {
                Remove(item);
            }

            add.Clear();
            remove.Clear();
        }

        private void Load()
        {
            if(!isCached)
            {
                loader.Invoke();
            }
        }

        private void Load(Action a)
        {
            Load();
            a.Invoke();
        }

        private R Load<R>(Func<R> f)
        {
            Load();
            return f.Invoke();
        }
    }
}