GLOBAL.window = GLOBAL
require "../../public/smart_search.coffee"

describe "search query parser", ->
  beforeEach ->
    @smartSearch = new window.SmartSearch
    @parse = (string) -> @smartSearch.parseSearch(string)

  it "should interpret a query term with a colon as a key/value pair", ->
    expect(@parse("foo:bar")["foo"]).toEqual "bar"

  it "should ignore extra colons afterwards", ->
    expect(@parse("foo:bar:baz")["foo"]).toEqual "bar:baz"

  it "should parse an empty key to path", ->
    expect(@parse(":foo")["paths"]).toEqual(["foo"])

  it "should allow for a comma-separated list, including spaces", ->
    expect(@parse("repos:db, barkeep,coffee")["repos"]).toEqual "db,barkeep,coffee"

  it "should allow for spaces after the colon in a search term", ->
    expect(@parse("repos: barkeep authors: caleb")).toEqual { paths: [], repos: "barkeep", authors: "caleb" }

  it "should gracefully handle (ignore) weird leading colons", ->
    expect(@parse(":foo:bar, baz")["foo"]).toEqual "bar,baz"

  it "should handle arbitrary amounts of whitespace", ->
    expect(@parse("    repos:  foo,  bar, baz      authors:joe,bob,   jimmy")).toEqual
      paths: []
      repos: "foo,bar,baz"
      authors: "joe,bob,jimmy"

  it "should gracefully handle a trailing comma", ->
    expect(@parse("foo:bar,baz,")["foo"]).toEqual "bar,baz"

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
