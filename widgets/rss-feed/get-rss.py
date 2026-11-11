#!/usr/bin/env python3
import sys
import os
import json
import re
import time
import hashlib
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

CACHE_DIR = os.path.expanduser('~/.cache/omarchy/rss')
DEFAULT_FEEDS = [
    {"name": "Hacker News", "url": "https://news.ycombinator.com/rss"},
    {"name": "Arch Linux", "url": "https://archlinux.org/feeds/news/"},
    {"name": "Phoronix Linux", "url": "https://www.phoronix.com/rss.php"},
    {"name": "The Verge", "url": "https://www.theverge.com/rss/index.xml"}
]

def clean_html(raw_html):
    if not raw_html:
        return ""
    # Remove HTML tags
    clean = re.sub(r'<[^>]+>', '', raw_html)
    # Unescape common entities
    clean = clean.replace('&amp;', '&').replace('&lt;', '<').replace('&gt;', '>').replace('&quot;', '"').replace('&#39;', "'").replace('&nbsp;', ' ')
    # Collapse whitespace
    return re.sub(r'\s+', ' ', clean).strip()

def format_time_ago(dt):
    if not dt:
        return ""
    now = datetime.now(timezone.utc)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    diff = now - dt
    secs = int(diff.total_seconds())
    if secs < 0:
        return "just now"
    if secs < 60:
        return f"{secs}s ago"
    mins = secs // 60
    if mins < 60:
        return f"{mins}m ago"
    hours = mins // 60
    if hours < 24:
        return f"{hours}h ago"
    days = hours // 24
    if days == 1:
        return "yesterday"
    if days < 7:
        return f"{days}d ago"
    return dt.strftime("%b %d")

def parse_date(date_str):
    if not date_str:
        return None
    try:
        return parsedate_to_datetime(date_str)
    except Exception:
        pass
    # Try ISO formats (Atom)
    try:
        clean = date_str.replace('Z', '+00:00')
        return datetime.fromisoformat(clean)
    except Exception:
        pass
    return None

def fetch_feed(url, force=False):
    os.makedirs(CACHE_DIR, exist_ok=True)
    url_hash = hashlib.md5(url.encode('utf-8')).hexdigest()
    cache_file = os.path.join(CACHE_DIR, f"{url_hash}.json")

    # Use cache if fresh (< 15 mins) and not force
    if not force and os.path.exists(cache_file):
        try:
            mtime = os.path.getmtime(cache_file)
            if time.time() - mtime < 900: # 15 minutes
                with open(cache_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
        except Exception:
            pass

    req = urllib.request.Request(
        url,
        headers={
            'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) OmarchyDesktopWidgets/1.2.6'
        }
    )

    try:
        with urllib.request.urlopen(req, timeout=8) as response:
            content = response.read()
    except Exception as e:
        # Fallback to stale cache if network fails
        if os.path.exists(cache_file):
            try:
                with open(cache_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    data['cached'] = True
                    return data
            except Exception:
                pass
        return {"status": "error", "error": str(e), "items": []}

    try:
        root = ET.fromstring(content)
    except Exception as e:
        return {"status": "error", "error": f"Failed to parse XML: {e}", "items": []}

    items = []
    feed_title = ""

    # Check for RSS 2.0 (<channel><item>)
    channel = root.find('channel')
    if channel is not None:
        title_el = channel.find('title')
        if title_el is not None and title_el.text:
            feed_title = clean_html(title_el.text)

        for it in channel.findall('item')[:25]:
            t_el = it.find('title')
            l_el = it.find('link')
            d_el = it.find('description')
            pub_el = it.find('pubDate')
            creator_el = it.find('{http://purl.org/dc/elements/1.1/}creator')

            title = clean_html(t_el.text) if t_el is not None and t_el.text else "Untitled"
            link = l_el.text.strip() if l_el is not None and l_el.text else ""
            raw_desc = d_el.text if d_el is not None and d_el.text else ""
            desc = clean_html(raw_desc)[:160]
            pub_raw = pub_el.text.strip() if pub_el is not None and pub_el.text else ""
            dt = parse_date(pub_raw)
            author = creator_el.text.strip() if creator_el is not None and creator_el.text else ""

            items.append({
                "title": title,
                "link": link,
                "snippet": desc,
                "time_ago": format_time_ago(dt),
                "author": author
            })
    else:
        # Check for Atom (<feed><entry>)
        ns = {'atom': 'http://www.w3.org/2005/Atom'}

        # An Element with no children is falsy, so "find(a) or find(b)" would
        # throw away every match; compare against None instead.
        def first(node, *paths):
            for path in paths:
                el = node.find(path, ns)
                if el is not None:
                    return el
            return None

        # An entry can carry several links (self, edit, replies, alternate).
        # The article is the alternate one, ideally HTML; rel defaults to
        # "alternate" when absent.
        def pick_link(entry):
            links = entry.findall('atom:link', ns) or entry.findall('link')
            alternate = ""
            fallback = ""
            for l_el in links:
                href = (l_el.attrib.get('href') or l_el.text or "").strip()
                if not href:
                    continue
                if l_el.attrib.get('rel', 'alternate') == 'alternate':
                    if l_el.attrib.get('type', 'text/html') in ('text/html', 'application/xhtml+xml'):
                        return href
                    alternate = alternate or href
                fallback = fallback or href
            return alternate or fallback

        title_el = first(root, 'atom:title', 'title')
        if title_el is not None and title_el.text:
            feed_title = clean_html(title_el.text)

        entries = root.findall('atom:entry', ns) or root.findall('entry')
        for entry in entries[:25]:
            t_el = first(entry, 'atom:title', 'title')
            link = pick_link(entry)

            s_el = first(entry, 'atom:summary', 'summary', 'atom:content', 'content')
            pub_el = first(entry, 'atom:published', 'published', 'atom:updated', 'updated')
            a_el = entry.find('atom:author/atom:name', ns)

            title = clean_html(t_el.text) if t_el is not None and t_el.text else "Untitled"
            desc = clean_html(s_el.text if s_el is not None and s_el.text else "")[:160]
            pub_raw = pub_el.text.strip() if pub_el is not None and pub_el.text else ""
            dt = parse_date(pub_raw)
            author = a_el.text.strip() if a_el is not None and a_el.text else ""

            items.append({
                "title": title,
                "link": link,
                "snippet": desc,
                "time_ago": format_time_ago(dt),
                "author": author
            })

    result = {
        "status": "ok",
        "feed_title": feed_title,
        "feed_url": url,
        "items": items
    }

    try:
        with open(cache_file, 'w', encoding='utf-8') as f:
            json.dump(result, f, indent=2)
    except Exception:
        pass

    return result

def prompt_add_feed_dialog():
    import subprocess
    import shutil

    # omarchy-file-select or zenity entry dialog
    zenity = shutil.which('zenity')
    if zenity:
        try:
            p = subprocess.run(
                [zenity, '--entry', '--title=Add RSS / Atom Feed',
                 '--text=Enter the full RSS or Atom feed URL (e.g. https://example.com/rss):'],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True
            )
            if p.returncode == 0 and p.stdout.strip():
                url = p.stdout.strip()
                if not url.startswith('http://') and not url.startswith('https://'):
                    url = 'https://' + url
                return url
        except Exception:
            pass
    return None

def main():
    if len(sys.argv) > 1:
        arg = sys.argv[1].strip()
        if arg == "add_dialog":
            url = prompt_add_feed_dialog()
            if url:
                data = fetch_feed(url, force=True)
                title = data.get('feed_title') or url.replace('https://', '').replace('http://', '').split('/')[0]
                print(json.dumps({
                    "status": "feed_added",
                    "url": url,
                    "name": title,
                    "items_count": len(data.get('items', []))
                }))
            else:
                print(json.dumps({"status": "cancelled"}))
            return
        elif arg.startswith("http://") or arg.startswith("https://"):
            force = (len(sys.argv) > 2 and sys.argv[2] == "--force")
            print(json.dumps(fetch_feed(arg, force=force)))
            return

    # Default: fetch Hacker News
    default_url = DEFAULT_FEEDS[0]["url"]
    print(json.dumps(fetch_feed(default_url)))

if __name__ == '__main__':
    main()
