root = exports ? window

# TabRecency associates a logical timestamp with each tab id.  These are used to provide an initial
# recency-based ordering in the tabs vomnibar (which allows jumping quickly between recently-visited tabs).
class TabRecency
  timestamp: 1
  current: -1
  cache: {}
  lastVisited: null
  lastVisitedTime: null
  timeDelta: 500 # Milliseconds.

  constructor: ->
    chrome.tabs.onActivated.addListener (activeInfo) => @register activeInfo.tabId
    chrome.tabs.onRemoved.addListener (tabId) => @deregister tabId

    chrome.tabs.onReplaced.addListener (addedTabId, removedTabId) =>
      @deregister removedTabId
      @register addedTabId

    chrome.windows.onFocusChanged.addListener (wnd) =>
      if wnd != chrome.windows.WINDOW_ID_NONE
        chrome.tabs.query {windowId: wnd, active: true}, (tabs) =>
          @register tabs[0].id if tabs[0]

  register: (tabId) ->
    currentTime = new Date()
    # Register tabId if it has been visited for at least @timeDelta ms.  Tabs which are visited only for a
    # very-short time (e.g. those passed through with `5J`) aren't registered as visited at all.
    if @lastVisitedTime? and @timeDelta <= currentTime - @lastVisitedTime
      @cache[@lastVisited] = ++@timestamp

    @current = @lastVisited = tabId
    @lastVisitedTime = currentTime

  deregister: (tabId) ->
    if tabId == @lastVisited
      # Ensure we don't register this tab, since it's going away.
      @lastVisited = @lastVisitedTime = null
    delete @cache[tabId]

  # Recently-visited tabs get a higher score (except the current tab, which gets a low score).
  recencyScore: (tabId) ->
    @cache[tabId] ||= 1
    if tabId == @current then 0.0 else @cache[tabId] / @timestamp

  # Returns a list of tab Ids sorted by recency, most recent tab first.
  getTabsByRecency: ->
    tabIds = (tId for own tId of @cache)
    tabIds.sort (a,b) => @cache[b] - @cache[a]
    tabIds.map (tId) -> parseInt tId

BgUtils =
  tabRecency: new TabRecency()

root.BgUtils = BgUtils
