'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter_bootstrap.js": "693ebbeb8c4caef7e688d6722115c175",
"version.json": "c5e8f88eb13aa2943830cdbcfd1ca15e",
"index.html": "962da60c7038d57fc865a09419c1680c",
"/": "962da60c7038d57fc865a09419c1680c",
"main.dart.js": "6ae9c24dd23726412fb05acfb0cc651f",
"flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"manifest.json": "5bf581b7249d4a450c62c54a5c840b76",
"assets/AssetManifest.json": "1101788fe642d84ca2c053ea231a98fe",
"assets/NOTICES": "e1f03a56b7025478b961ad8d2f97100c",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/AssetManifest.bin.json": "b0f8fe5272abe1be3594d97dd46cd35b",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin": "138dbb9bf45eaf774ee4405d9bb44347",
"assets/fonts/MaterialIcons-Regular.otf": "69b770ec8eacbb5dc2d53f6e14e82328",
"assets/assets/icons/search.svg": "fd8ca78e886ea36183af451317e6f8e8",
"assets/assets/icons/angle-small-right.svg": "b29b878294a55d6e2b02439d068a57c8",
"assets/assets/icons/inbox_bold.svg": "9af97c39e854a9fe59c0519be350bd43",
"assets/assets/icons/home_bold.svg": "17714ebd97f03868db503200a3d7bf41",
"assets/assets/icons/attendance_line.svg": "dc62306cbaa65df7575ebca1a5f5081e",
"assets/assets/icons/languages.svg": "724ded2690de87bdf17a2ba11ad5641e",
"assets/assets/icons/profile_bold.svg": "2a69f6e228b9a1dce2eef7d372b09c85",
"assets/assets/icons/plus-small.svg": "68f52533d279a1175f80c1d5a0251cfd",
"assets/assets/icons/sign-out-alt.svg": "7ee1604a4dff559d6e08fa0e45968327",
"assets/assets/icons/gps.svg": "86821e25d2669a80c32bb26bb3eae26a",
"assets/assets/icons/vbus_icon.png": "bdb76124fcfef69ae857a06d03acf884",
"assets/assets/icons/seat_bold.svg": "4474d6eccbcf087220de427a31199e05",
"assets/assets/icons/minus-small.svg": "f0d875caf31b9d29a61995e5d369cf9e",
"assets/assets/icons/passengers.svg": "01392444bff3a945c64ea11ef1df7ee0",
"assets/assets/icons/info.svg": "8caee5812f2524e037e604f41f93241e",
"assets/assets/icons/profile_line.svg": "2f93d69a741e066d8bd2c59d578fb8ca",
"assets/assets/icons/condriv-final.svg": "a41ae246500eb69bc8beb2994e3e0477",
"assets/assets/icons/attendance_bold.svg": "6d8a00f7a94adaf871275e1ac4391c0e",
"assets/assets/icons/notification.svg": "bb9ad8c54e6909c32a7ef38019db9c8d",
"assets/assets/icons/send.svg": "7fe9c0660f98c1d1ebf2cb48d33aa377",
"assets/assets/icons/phone-call.svg": "273bf81e10494633c0a6e1eb0aefdb06",
"assets/assets/icons/google.svg": "648fa9faea73bcefeebcdd3c28c94c38",
"assets/assets/icons/bus.svg": "edc326fdacb21af51b7c12e2128156f4",
"assets/assets/icons/qr-scan.svg": "73e8750ef629f28dca42601e79b4ba07",
"assets/assets/icons/seat_line.svg": "daf5ebc627952b8600393db6c3abad2b",
"assets/assets/icons/pencil.svg": "6c814f96a063d855e67c0d76023e898c",
"assets/assets/icons/language.svg": "503d1a7a26d487ea44c7afc1932e89f2",
"assets/assets/icons/circle-user.svg": "534190b91f12c253a474a93bdc36dd53",
"assets/assets/icons/inbox_line.svg": "11239e74fbc0b82be45f924cc19bc1a8",
"assets/assets/icons/brightness.svg": "d3d0649930deede90cff449124d3cc3e",
"assets/assets/icons/studemp-final.svg": "c7d782e12c87723e0ecacf69f66f93a2",
"assets/assets/icons/history.svg": "0df2b4b4be8bea49082473856f8c6aa3",
"assets/assets/icons/home_line.svg": "5179a907ee9e27eae235b8a1706d60fa",
"assets/assets/animations/error.json": "d0b06ea9e68db9f2014206d49957b101",
"assets/assets/animations/loading.json": "8ce22b6a20af368314f50d6f35496fa0",
"assets/assets/animations/check.json": "b7c35ef330da70cbc817bcc1ae5cc96d",
"assets/assets/animations/bus_animation_js.json": "31b953023c3a2b31421a8ee21869e862",
"canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
