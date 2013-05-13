#!/usr/bin/env ruby

# how to compile SQLite3 to be used with tagnotes:
# http://www.sqlite.org/download.html
# sqlite-autoconf-3071601.tar.gz (1.77 MiB) 	
# CFLAGS="-Os -DSQLITE_ENABLE_FTS3=1 -DSQLITE_ENABLE_FTS3_PARENTHESIS=1 -DSQLITE_ENABLE_FTS4=1" ./configure && sudo make install


require 'rubygems'
require 'sqlite3'
require 'pp'

@db = nil

module Tagn

  def Tagn.opendb(path)
    @db = SQLite3::Database.open path
  end

  def Tagn.perr(str)
    puts "Error: " + str + "\n"
    raise str
  end

  def Tagn.dbwrap(path)
    # begin
    #   db = SQLite3::Database.open path
    #   yield db
    # rescue SQLite3::Exception => e
    #   perr "SQLite3::Exception: #{e}"
    # ensure
    #   db.close if db
    # end
    yield @db
  end

  def Tagn.dbpath_exists_or_die(dbpath)
    if not File.exists?(dbpath) then
      perr "db file \"#{dbpath}\" does not exist."
    else
      dbpath
    end
  end

  def Tagn.notepath_exists_or_die(notepath)
    if not File.exists?(notepath) then
      perr "input note file \"#{notepath}\" does not exist."
    else
      notepath
    end
  end

  def Tagn.createdb(dbname)
    dbpath = dbname
    if dbpath.nil? then
      perr "path expected, null given."
    end
    if File.exists?(dbpath) then
      perr "db file already exists; refusing and quitting."
    end
    opendb dbpath
    dbwrap(dbpath) do |db|

      # sqlite_autoindex comments below refer to:
      # http://www.sqlite.org/lang_createtable.html
      # paragraph: "INTEGER PRIMARY KEY columns aside, both UNIQUE and [...]"

      # TAGS table
      db.execute <<-EOtagstable

      CREATE TABLE IF NOT EXISTS tags (
        id   INTEGER PRIMARY KEY,
        name TEXT NOT NULL UNIQUE);

      EOtagstable
      # sqlite_autoindex id (primary key), name (unique)

      # NOTES table
      db.execute <<-EOnotestable

      CREATE TABLE IF NOT EXISTS notes (
        id     INTEGER PRIMARY KEY,
        title  TEXT NOT NULL DEFAULT '',
        text   TEXT NOT NULL DEFAULT '',
        created_on DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        modified_on DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP);

      EOnotestable
      # sqlite_autoindex id (primary key)

      # NOTES_TAGS linking table
      db.execute <<-EOnotestagstable

      CREATE TABLE IF NOT EXISTS notes_tags (
        note_id INTEGER NOT NULL REFERENCES notes(id),
        tag_id  INTEGER NOT NULL REFERENCES tags(id),
        PRIMARY KEY (note_id, tag_id));

      EOnotestagstable
      # sqlite_autoindex (note_id, tag_id) (primary key)

      db.execute "
      CREATE INDEX notes_tags_note_id_idx ON notes_tags (note_id ASC);"

      db.execute "
      CREATE INDEX notes_tags_tag_id_idx ON notes_tags (tag_id ASC);"

      db.execute "
      CREATE VIRTUAL TABLE fulltext USING fts4(title,text);"
      # use tokenize=porter?

      # tables = db.execute "
      # SELECT * FROM sqlite_master WHERE type = 'table'; "

      # TODO: check for consistency before printing 'success!'
      puts "\nDatabase created succesfully at #{dbpath}\n\n"
    end
  end

  # create new note
  def Tagn.new(dbname, title)
    dbpath = dbpath_exists_or_die(dbname)
    title = title || "untitled"

    note_id = nil

    dbwrap(dbpath) do |db|
      stmt = db.prepare "INSERT INTO notes(title) VALUES (?);"
      stmt.bind_param(1, title)
      stmt.execute
      stmt.close

      note_id = db.last_insert_row_id

      stmt = db.prepare "
      INSERT INTO fulltext(docid,title) VALUES (#{note_id},?);"
      stmt.bind_param(1, title)
      stmt.execute
      stmt.close

      # new_title = title.downcase.gsub(/[^0-9a-z_-]/,"").gsub(/ /,'')
      # filename = "#{new_title}##{note_id}.tagn"
      # puts "created file: #{filename}"
      # File.open(filename, 'w') do |f|
      #   f.puts "TAGS: "
      #   f.puts "TITLE: #{title}\n"
      # end
      # system("emacsclient --no-wait #{filename}")
    end

    note_id
  end

  # file#8.tagn => 8
  def Tagn.get_noteid_from_file(file)
    note_id_match = file.match(/#(\d+)\./)
    if note_id_match.nil?
      perr "input note file \"#{file}\" does not conform to expected format <name>#<id>.tagn (e.g. note#8.tagn), so the ID could not be found."
    else
      note_id_match[1].to_i
    end
  end

  def Tagn.split(str)
    str.downcase.scan(/[a-z]+/)
  end

  # update note from file
  def Tagn.set(dbname, note_id, title, text, tags_)
    dbpath = dbpath_exists_or_die(dbname)
    tags = split(tags_)
    #notefile = notepath_exists_or_die(filename)

    # # grab data from TAGS: and TITLE: lines (can be in any order
    # # so long as they're the first 2 lines)
    # lines = IO.readlines(notefile)
    # [0,1].each do |n|
    #   arr = lines[n].split(/:/,2)
    #   line_type = arr[0].downcase
    #   line_content = arr[1]

    #   if line_type == "tags"
    #     tags = line_content.strip.gsub(/,/," ").gsub(/\s+/," ").downcase.split(/ /)
    #   elsif line_type == "title"
    #     title = line_content
    #   end
    # end

    dbwrap(dbpath) do |db|

      # save the note in the NOTES table
      stmt = db.prepare <<-EOupdate
      UPDATE notes SET
        text = ?,
        title = ?
        WHERE id=#{note_id};"
    EOupdate

      stmt.bind_param(1, text)
      stmt.bind_param(2, title.strip)
      stmt.execute
      stmt.close

      # save the note in the FULLTEXT table
      stmt = db.prepare <<-EOupdate
      UPDATE fulltext SET
        text = ?,
        title = ?
        WHERE docid=#{note_id};"
    EOupdate

      stmt.bind_param(1, text)
      stmt.bind_param(2, title.strip)
      stmt.execute
      stmt.close

      new_notetags = {} # new for this note
      new_tags = {} # globally new

      tags.each do |t|
        tag_id = nil
        tag_id_rows = db.execute "SELECT id FROM tags WHERE name=\"#{t}\";"

        # tag doesn't exist yet
        if tag_id_rows.empty? then
          db.execute "INSERT INTO tags (name) VALUES (\"#{t}\");"
          tag_id = db.last_insert_row_id
          new_tags[tag_id] = t
        else  # tag already exists
          tag_id = tag_id_rows[0][0]
        end
        
        # find out if this note has tag t
        notes_tags_key_rows = db.execute <<-EOselect
        SELECT * FROM notes_tags
        WHERE note_id=#{note_id}
        AND   tag_id=#{tag_id};
      EOselect

        # if this is a new tag for this note, then add it to this note
        if notes_tags_key_rows.empty? then
          db.execute <<-EOinsert
          INSERT INTO notes_tags (note_id,tag_id)
                      VALUES (#{note_id},#{tag_id});
        EOinsert
          new_notetags[tag_id] = t
        end # if
      end # tags.each

      # find current tags for this note
      current_notetags = db.execute <<-EOselect
      SELECT t.name, t.id
      FROM tags t
      JOIN notes_tags nt on nt.tag_id = t.id
      WHERE nt.note_id=#{note_id};
    EOselect

      # find out if any tags in the DB for this note were deleted from the file
      current_notetags_hash = Hash[*current_notetags.flatten]
      current_notetags_arr = current_notetags_hash.keys
      tags_to_delete = current_notetags_arr - tags

      # if tags were deleted from the file, delete them from the DB
      deleted_tags = {}
      tags_to_delete.each do |dt|
        tagid_to_delete = current_notetags_hash[dt]
        db.execute <<-EOdelete
        DELETE FROM notes_tags
        WHERE note_id=#{note_id}
        AND   tag_id=#{tagid_to_delete};
      EOdelete
        deleted_tags[tagid_to_delete] = dt
      end

      # notify user of tags deleted from note
      if not deleted_tags.empty?
        puts "tags deleted from note #{note_id}: #{deleted_tags.inspect}"
      end
      
      # notify user of new tags
      if not new_tags.empty?
        puts "brand new tags: #{new_tags.inspect}"
      end

      # notify user of new notetags
      if not new_notetags.empty?
        puts "tags added to note #{note_id}: #{new_notetags.inspect}"
      end
    end # dbwrap

    puts "update succesful.\n"
  end

  def Tagn.get(dbname, tokens) # my.db tag1 tag2 tag3 ...
    dbpath = dbpath_exists_or_die(dbname)
    tokens = tokens.scan(/[#a-z]+/)
    tokens = tokens.partition{|x| x[0] == '#'[0] }
    tags = tokens[0].map{|t| t[1..-1]}
    words = tokens[1]
    tags_text = tags.map{|t| "\"#{t}\""}.join(",")
    words_text = "#{words.join(" ")}"

    result = nil

    dbwrap(dbpath) do |db|
      # note_rows = db.execute <<-EOtags
      #   SELECT n.id, n.title
      #   FROM notes n
      #   JOIN notes_tags nt ON nt.note_id = n.id
      #   JOIN tags t ON nt.tag_id = t.id
      #   WHERE t.name in (#{tags_text});"
      # EOtags

      q = <<-EOstuff
        SELECT distinct n.id, n.title
        FROM notes n
        LEFT JOIN notes_tags nt ON nt.note_id = n.id
        LEFT JOIN tags t ON nt.tag_id = t.id
        JOIN fulltext ft ON ft.docid = n.id
        WHERE 1=1
    EOstuff
      unless tags_text.empty?
        q = q + "AND t.name in (#{tags_text})\n"
      end
      unless words_text.empty?
        q = q + "AND ft.fulltext MATCH '#{words_text}'"
      end
      q = q + ";"
      print q
      $stdout.flush
      note_rows = db.execute q
      pp note_rows

      puts "\nNotes found:\n--------------\n| ID | title\n--------------"
      note_rows.each do |nr|
        id = nr[0]
        title = nr[1] || "untitled"
        puts "| #{id}  |  #{title}"
      end # note_rows.each
      puts "--------------\n\n"
      result = note_rows
    end # dbwrap
    result
  end

  def Tagn.edit(dbname, noteid)
    dbpath = dbpath_exists_or_die(dbname)
    note_id = noteid.to_i

    result = {}

    dbwrap(dbpath) do |db|
      # retrieve note if it exists
      note_row = db.execute <<-EOnote
      SELECT * FROM notes WHERE id=#{note_id};
    EOnote
      
      # we end here if note doesn't exist
      if note_row.empty? then
        perr "No note found."
      end

      note = note_row[0]
      note_id = note[0]
      title = note[1]
      text = note[2]
      p note_row

      # find all tags for this note
      note_tags_rows = db.execute <<-EOtags
      SELECT t.name
      FROM tags t
      JOIN notes_tags nt ON nt.tag_id = t.id
      WHERE nt.note_id = #{note_id};
    EOtags

      # join notetags - TODO: does this work when there are no tags?
      tags = note_tags_rows.flatten.join(" ") # I don't like commas as seps

      result = {
        :title => title,
        :text => text,
        :tags => tags }

      # prepare file and open it
      # new_title = title.downcase.gsub(/[^0-9a-z_-]/,"").gsub(/ /,'')
      # filename = "#{new_title}##{note_id}.tagn"
      # puts "created file: #{filename}"
      # File.open(filename, 'w') do |f|
      #   f.puts "TAGS: #{note_tags}"
      #   f.puts "TITLE: #{title}"
      #   f.puts text
      # end
      # system("emacsclient --no-wait #{filename}")
    end # dbwrap
    result
  end

  # full-text search
  def Tagn.fts(dbname, word)
    dbpath = dbpath_exists_or_die(dbname)

    dbwrap(dbpath) do |db|
      stmt = db.prepare "
      SELECT docid, title, snippet(fulltext) FROM fulltext WHERE fulltext MATCH ?;"
      stmt.bind_param(1, word)
      r = stmt.execute
      stmt.close
    end
  end

end

def blah
  begin
    db = SQLite3::Database.new ":memory:"
    puts db.get_first_value 'SELECT SQLITE_VERSION()'
  rescue SQLite3::Exception
    puts "Exception occurred:\n"
    puts e
  ensure
    db.close if db
  end
end

#main
