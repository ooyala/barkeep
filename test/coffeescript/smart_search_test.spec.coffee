GLOBAL.window = GLOBAL
require "../../public/smart_search.coffee"

describe "search query parser", ->
  beforeEach ->
    @smartSearch = new window.SmartSearch
    @parsed = (string) -> @smartSearch.parseSearch(string)

  it "should interpret a query term with a colon as a key/value pair", ->
    expect(@parsed("foo:bar")["foo"]).toEqual "bar"
