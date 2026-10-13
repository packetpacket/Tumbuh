const CACHE='tumbuh-shell-v4';
const ASSETS=['./','./index.html','./style.css','./app.js','./core.mjs','./importer.mjs','./security.mjs','./pwa.mjs','./config.js','./indicators.json','./manifest.webmanifest','./icons/icon-192.png','./icons/icon-512.png','./vendor/exceljs.min.js','./vendor/xlsx.full.min.js','./vendor/supabase.min.js'];
const urls=new Set(ASSETS.map(path=>new URL(path,self.registration.scope).href));
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(ASSETS))));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key.startsWith('tumbuh-shell-')&&key!==CACHE).map(key=>caches.delete(key)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',event=>{
 const request=event.request,url=new URL(request.url);
 // Never store OAuth callbacks, API responses, or child data.
 if(request.method!=='GET'||url.origin!==self.location.origin||url.search||url.hash||!urls.has(url.href))return;
 if(request.mode==='navigate'){
  event.respondWith(fetch(request).catch(()=>caches.match(new URL('./index.html',self.registration.scope).href)));return;
 }
 event.respondWith(caches.match(request).then(cached=>cached||fetch(request)));
});
