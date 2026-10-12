#!/usr/bin/env python3
"""Probe official NCES IPEDS page markup for real C2025_A download links.

Read-only, no cookie/token/credentials printed. Used to identify official ZIP.
"""
from html.parser import HTMLParser
import re
import urllib.request

URLS=[
 "https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx?fromIpeds=true&gotoReportId=7",
 "https://nces.ed.gov/ipeds/use-the-data/download-complete-data-files",
]
class Anchors(HTMLParser):
    def __init__(self): super().__init__();self.items=[];self.cur=None
    def handle_starttag(self,tag,attrs):
        if tag=="a": self.cur={"attrs":dict(attrs),"text":""}
    def handle_data(self,data):
        if self.cur is not None:self.cur["text"]+=data
    def handle_endtag(self,tag):
        if tag=="a" and self.cur:
            self.items.append(self.cur);self.cur=None

for u in URLS:
    try:
        req=urllib.request.Request(u,headers={"User-Agent":"Mozilla/5.0"})
        with urllib.request.urlopen(req,timeout=35) as response:
            html=response.read(3_500_000).decode("utf-8","replace")
            print("Page:",u,"status:",response.status,"len:",len(html))
        a=Anchors();a.feed(html)
        anchors=[v for v in a.items if "C2025_A" in v["text"].upper() or "C2025_A" in str(v["attrs"]).upper()]
        print("Matching anchors:",len(anchors))
        for v in anchors[:8]:
            attrs=v["attrs"]
            print("  text:",v["text"][:80],
                  "href:",str(attrs.get("href",""))[:220],
                  "onclick:",str(attrs.get("onclick",""))[:160])
        for match in list(re.finditer("C2025_A",html,re.I))[:4]:
            snippet=html[max(0,match.start()-350):match.end()+350]
            snippet=re.sub(r'(?i)(value\s*=\s*["\'])[^\']{200,}',r'\1[redacted]',snippet)
            print("near C2025_A:",' '.join(snippet.split())[:650])
    except Exception as exc:
        print("Page inaccessible:",u,type(exc).__name__,str(exc)[:120])
