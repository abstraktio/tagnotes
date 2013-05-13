require 'rubygems'
require 'tk'
require 'tk-helper'
require 'tagnotes'

$note_id = nil
$buffer = TkVariable.new

class GUI
  attr_accessor :note_id, :db, :notelist

  def initialize(dbname)
    @db = dbname
    pp @db
    @root = TkRoot.
      new.
      title("Tagnotes")

    @txtSearch = TkEntry.
      new(@root).
      pack("side"=>"top", "fill"=>"x")

    @lstNotes = TkListbox.
      new(@root).
      pack('side'=>'left', 'fill'=>'y').
      height(20)

    @txtTitle = TkEntry.
      new(@root).
      pack('side'=>'top', 'fill'=>'x')

    @txtText = TkText.
      new(@root).
      pack('side'=>'top', 'fill'=>'both', 'expand'=>'true').
      state("disabled").
      relief('sunken').
      borderwidth(1)

    @frmStatus = TkFrame.
      new(@root).
      pack('side'=>'bottom', 'fill'=>'x').
      height(25).
      relief('sunken').
      borderwidth(3)

    @txtTags = TkEntry.
      new(@root).
      pack('side'=>'bottom', 'fill'=>'x')

    @lblMinibuffer = TkLabel.
      new(@frmStatus).
      pack('side'=>'left').
      textvariable($buffer).
      text("Minibuffer")

    @lblModLED = TkLabel.
      new(@frmStatus).
      pack('side'=>'right').
      text("    ").
      background("#33AA33")


    #----------------------------------------

    @txtText.bind('<Modified>') do |e|
      # color LED red
      @lblModLED.background("#DD0000")
    end

    @txtSearch.onKeyUp do |e|
      if e.keysym == "Return"
        find_note
      end # if e.keysym
    end # txtSearch.onKeyUp

    @lstNotes.onSelect do |e|
      unless @lstNotes.curselection == []
        #a = @lstNotes.get(@lstNotes.curselection)
        # @txtNote.replace(1.0,'end',a)
        edit_note(@notelist[@lstNotes.curselection[0]][0])
      end
    end
    
    @root.onKeyUp do |e|
      if e.state == 8 # Command key
        case e.keysym
        when 'n'
          new_note
        when 's'
          puts "pressed Save"
          save_note
        when 'f'
          @txtSearch.focus
        end
      end
      if e.state == 4 # Ctrl key
        case e.keysym
        when 'x'
          $buffer.value = " C-x"

        when 'e' # for 'edit'
          $buffer.value = ''
          @txtText.focus

        when 'f' # for 'find' (cf. 'search')
          $buffer.value = ''
          @lstNotes.focus

        when 'r'
          $buffer.value = ''
          @txtTitle.focus

        when 'c'
          $buffer.value = ''
          @txtTags.focus

          # C-x C-s -> save
        when 's'
          $buffer.value += " C-s"
          case $buffer.value
          when " C-x C-s"
            save_note
            @txtText.modified = false
            @lblModLED.background("#33AA33")
            $buffer.value = ''
          when " C-s"
            $buffer.value = ''
            @txtSearch.focus
          end

        when 'n'
          $buffer.value += " C-n"
          case $buffer.value
          when ' C-x C-n'
            new_note
            $buffer.value = ''
          end

          # C-g -> cancels current command
        when 'g'
          $buffer.value = ''
        end
      end
    end # @root.onKeyUp

    Tagn.opendb("my.db")
  end # def init
    
  def save_note
    return unless @note_id
    Tagn.set(@db, @note_id,
             @txtTitle.getText, @txtText.getText, @txtTags.getText)
    edit_note(@note_id)
  end

  def new_note
    id = Tagn.new(@db, 'untitled')
    edit_note(id)
  end

  def find_note
    @notelist = Tagn.get(@db, @txtSearch.getText)
    @lstNotes.populate(@notelist.map{|i| i[1]})
  end

  def edit_note(note_id)
    @txtText.state("normal")
    @note_id = note_id
    note = Tagn.edit(@db, note_id)
    @txtTitle.setText note[:title]
    @txtText.setText  note[:text]
    @txtTags.setText  note[:tags]
  end
end

#txtNote.setText("note\n")
#txtSearch.setText('search')
#p txtNote.getText
#p txtSearch.getText
def main
  gui = GUI.new("my.db")
  `/usr/bin/osascript -e 'tell app "Finder" to set frontmost of process "ruby" to true'`
  Tk.mainloop
end

main



=begin
button = TkButton.new(root) {
  text "Hello..."
  command proc {
    p "...world!"
  }
}
button.pack()
Tk.mainloop()
=end


#atriz ximenez
#ellen roche
#musas cerveja
