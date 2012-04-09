GLOBAL.window = GLOBAL
require "../../public/smart_search.coffee"

describe "search query parser", ->
  beforeEach ->
    @smartSearch = new window.SmartSearch
    @parse = (string) -> @smartSearch.parseSearch(string)
    @parsePartialQuery = (string) -> @smartSearch.parsePartialQuery(string)

  it "should interpret a query term with a colon as a key/value pair", ->
    expect(@parse("foo:bar")["foo"]).toEqual "bar"

  it "should identify the key and partial term correctly for a query term with a colon", ->
    expect(@parsePartialQuery("foo:bar")).toEqual
      key: "foo:",
      value: "bar",
      unrelatedPrefix: "foo:",
      searchType: "value"

    expect(@parsePartialQuery("foo:bar ")).toEqual
      key: "",
      value: "",
      unrelatedPrefix: "foo:bar ",
      searchType: "key"

  it "should ignore extra colons afterwards", ->
    expect(@parse("foo:bar:baz")["foo"]).toEqual "bar:baz"
    expect(@parsePartialQuery("foo:bar:baz")).toEqual
      key: "foo:bar:",
      value: "baz",
      unrelatedPrefix: "foo:bar:",
      searchType: "value"

  it "should parse an empty key to path", ->
    expect(@parse(":foo")["paths"]).toEqual(["foo"])

  it "should allow for a comma-separated list, including spaces", ->
    expect(@parse("repos:db, barkeep,coffee")["repos"]).toEqual "db,barkeep,coffee"
    expect(@parsePartialQuery("repos:db, barkeep,coffee")).toEqual
      key: "repos:",
      value: "coffee",
      unrelatedPrefix: "repos:db,barkeep,",
      searchType: "value"

  it "should allow for spaces after the colon in a search term", ->
    expect(@parse("repos: barkeep authors: caleb")).toEqual { paths: [], repos: "barkeep", authors: "caleb" }
    expect(@parsePartialQuery("repos: barkeep authors: caleb")).toEqual
      key: "authors:",
      value: "caleb",
      unrelatedPrefix: "repos:barkeep authors:",
      searchType: "value"

  it "should gracefully handle (ignore) weird leading colons", ->
    expect(@parse(":foo:bar, baz")["foo"]).toEqual "bar,baz"

  it "should handle arbitrary amounts of whitespace", ->
    expect(@parse("    repos:  foo,  bar, baz      authors:joe,bob,   jimmy")).toEqual
      paths: []
      repos: "foo,bar,baz"
      authors: "joe,bob,jimmy"

    expect(@parsePartialQuery("    repos:  foo,  bar, baz      authors:joe,bob,   jimmy")).toEqual
      key: "authors:",
      value: "jimmy",
      unrelatedPrefix: " repos:foo,bar,baz authors:joe,bob,",
      searchType: "value"

  it "should gracefully handle a trailing comma", ->
    expect(@parse("foo:bar,baz,")["foo"]).toEqual "bar,baz"
    expect(@parsePartialQuery("foo:bar,baz,")).toEqual
      key: "foo:",
      value: "",
      unrelatedPrefix: "foo:bar,baz,",
      searchType: "value"

  it "should allow for using paths like any other key", ->
    expect(@parse("paths: foo, bar,baz")["paths"]).toEqual ["foo,bar,baz"]

  it "should allow for setting paths by not specifying a key", ->
    expect(@parse("foo bar baz repos:blah paths:some/path")).toEqual
      paths: ["foo", "bar", "baz", "some/path"]
      repos: "blah"

  it "should handle sha in the query", ->
    sampleShas = ["0e7d9bd88dfe54ca05356edec1fdf293d1e61658", "0e7d9bd88d", "0e7d9bd"]
    for sampleSha in sampleShas
      expect(@parse(sampleSha)["sha"]).toEqual(sampleSha)

  it "should handle sha plus another search term", ->
    expect(@parse("0e7d9bd repos:barkeep")).toEqual
      paths: []
      sha: "0e7d9bd"
      repos: "barkeep"

  it "should not confuse words for sha", ->
    sampleWords = ["sevens", "migrations"]
    expect(@parse(word)["paths"]).toEqual([word]) for word in sampleWords

  it "should allow for some synonyms instead of the intended keywords", ->
    for keyword, synonym of { branches: "branch", authors: "author", repos: "repo" }
      expect(@parse("#{synonym}: foobar")[keyword]).toEqual "foobar"
