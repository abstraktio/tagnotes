#!/usr/bin/ruby

require 'rubygems'
require 'sqlite3'
require 'pp'
require 'tagnotes'

def main
  action = ARGV[0]
  case action

    when "createdb" # dbname
    Tagn.createdb(ARGV[1])

    when "new" # dbname, title
    Tagn.new(ARGV[1],ARGV[2])

    when "set", "save" # dbname, filename
    Tagn.set(ARGV[1],ARGV[2]) # TODO: update modified_on

    when "get", "find" # dbname, tags
    Tagn.get(ARGV[1],ARGV[2..-1])

    when "edit" # dbname, noteid
    Tagn.edit(ARGV[1],ARGV[2])

    when "fts" # dbname, word
    Tagn.fts(ARGV[1],ARGV[2])

    else
    Tagn.perr "command not recognized: \"#{action}\"."

  end
end

main