/*
 * Live CSS will monitor <link> tags on the page and poll the server for changes to the CSS. This enables you
 * to refresh styles without disrupting the state of the view, and the page updates itself without you
 * having to switch from your editor to the browser and hit refresh.
 *
 * Usage:
 * livecss.watchAll() - starts polling all <link> tags in the current page for changes.
 *
 * If you want more fine grained control over which CSS is being autoreloaded:
 * livecss.watch(linkElement) - start watching a single <link> element for changes.
 * livecss.unwatchAll()
 * livecss.unwatch(linkElement)
 *
 * For convenience, livecss will call watchAll() right away if the page has "startlivecss=true" in the URL's
 * query string.
 */
var livecss = {
  // How often to poll for changes to the CSS.
  pollFrequency: 1000,
  outstandingRequests: {}, // stylesheet url => boolean
  filesLastModified: {}, // stylesheet url => last modified timestamp
  watchTimers: {}, // stylesheet url => timer ID

  /*
   * Begins polling all link elements on the current page for changes.
   */
  watchAll: function() {
    this.unwatchAll();
    var timerId = setInterval(this.proxy(function() {
      var linkElements = document.getElementsByTagName("link");
      var validMediaTypes = ["screen", "handheld", "all", ""];
      for (var i = 0; i < linkElements.length; i++) {
        var media = (linkElements[i].getAttribute("media") || "").toLowerCase();
        if (linkElements[i].getAttribute("rel") == "stylesheet"
            && livecss.indexOf(validMediaTypes, media) >= 0
            && this.isLocalUrl(linkElements[i].getAttribute("href"))) {
          this.refreshLinkElement(linkElements[i]);
        }
      }
    }), this.pollFrequency);
    this.watchTimers["all"] = timerId;
  },

  watch: function(linkElement) {
    var url = linkElement.getAttribute("href");
    this.unwatch(url);
    this.watchTimers[url] = setInterval(this.proxy(function() {
      var linkElement = this.linkElementWithHref(url);
      this.refreshLinkElement(linkElement);
    }), this.pollFrequency);
  },

  unwatchAll: function() {
    for (var url in this.watchTimers)
      this.unwatch(url);
  },

  unwatch: function(url) {
    if (this.watchTimers[url] != null) {
      clearInterval(this.watchTimers[url]);
      delete this.watchTimers[url];
      delete this.outstandingRequests[url];
    }
  },

  linkElementWithHref: function(url) {
    var linkElements = document.getElementsByTagName("link");
    for (var i = 0; i < linkElements.length; i++)
      if (linkElements[i].href == url)
        return linkElements[i]
  },

  /*
   * Replaces a link element with a new one for the given URL. This has to wait for the new <link> to fully
   * load, because simply changing the href on an existing <link> causes the page to flicker.
   */
  replaceLinkElement: function(linkElement, stylesheetUrl) {
    var parent = linkElement.parentNode;
    var sibling = linkElement.nextSibling;
    var url = this.addCacheBust(linkElement.href);

    var newLinkElement = document.createElement("link");
    newLinkElement.href = url;
    newLinkElement.setAttribute("rel", "stylesheet");

    if (sibling)
      parent.insertBefore(newLinkElement, sibling);
    else
      parent.appendChild(newLinkElement);

    // We're polling to check whether the CSS is loaded, because firefox doesn't support an onload event
    // for <link> elements.
    var loadingTimer = setInterval(this.proxy(function() {
      if (!this.isCssElementLoaded(newLinkElement)) return;
      if (typeof(console) != "undefined")
        console.log("CSS refreshed:", this.removeCacheBust(url));
      clearInterval(loadingTimer);
      delete this.outstandingRequests[this.removeCacheBust(url)];
      parent.removeChild(linkElement);
    }), 100);
  },

  /*
   * Refreshes the provided linkElement if it's changed. We issue a HEAD request for the CSS. If its
   * last-modified header is changed, we remove and re-add the <link> element to the DOM which trigger a
   * re-render from the browser. This uses a cache-bust querystring parameter to ensure we always bust through
   * the browser's cache.
   */
  refreshLinkElement: function(linkElement) {
    var url = this.removeCacheBust(linkElement.getAttribute("href"));
    if (this.outstandingRequests[url]) return;
    var request = new XMLHttpRequest();
    this.outstandingRequests[url] = request;
    var cacheBustUrl = this.addCacheBust(url);

    request.onreadystatechange = this.proxy(function(event) {
      if (request.readyState != 4) return;
      delete this.outstandingRequests[url];
      if (request.status != 200 && request.status != 304) return;
      var lastModified = Date.parse(request.getResponseHeader("Last-Modified"));
      if (!this.filesLastModified[url] || this.filesLastModified[url] < lastModified) {
        this.filesLastModified[url] = lastModified;
        this.replaceLinkElement(linkElement, cacheBustUrl);
      }
    });
    request.open("HEAD", cacheBustUrl);
    request.send(null);
  },

  isCssElementLoaded: function(cssElement) {
    // cssElement.sheet.cssRules will throw an error in firefox when the css file is not yet loaded.
    try { return (cssElement.sheet && cssElement.sheet.cssRules.length > 0); } catch(error) { }
    return false;
  },

  /* returns true for local urls such as: '/screen.css', 'http://mydomain.com/screen.css' */
  isLocalUrl: function(url) {
    var regexp = new RegExp("^\/|^" +
      document.location.protocol + "//" + document.location.host);
    return (url.search(regexp) == 0);
  },

  /*
   * Adds and removes a "cache_bust" querystring parameter to the given URLs. This is so we always bust
   * through the browser's cache when checking for updated CSS.
   */
  addCacheBust: function(url) { return this.removeCacheBust(url) + "?cache_bust=" + (new Date()).getTime(); },
  removeCacheBust: function(url) { return url.replace(/\?cache_bust=[^&]+/, ""); },

  /* A utility method to bind the value of "this". Equivalent to jQuery's proxy() function. */
  proxy: function(fn) {
    var self = this;
    return function() { return fn.apply(self, []); };
  },

  /* Unfortunately IE7 doesn't have this built-in. */
  indexOf: function(array, item) {
    for (var i = 0; i < array.length; i++) { if (array[i] == item) return i; }
    return -1;
  },

  /* A utility function for abstracting the difference between event listening in IE and other browsers. */
  addEventListener: function(object, event, fn) {
    object.attachEvent ? object.attachEvent("on" + event, fn) : object.addEventListener(event, fn, false);
  }
};

if (window.location.search.toString().indexOf("startlivecss=true") >= 0)
  livecss.addEventListener(window, "load", function() { livecss.watchAll(); });