require 'rubygems'
require 'tk'

class TkText
  def setText(str)
    self.replace(1.0,'end',str)
  end

  def getText
    # chomp, for tk adds extra \n
    self.get(1.0,'end').chomp
  end

  def onKeyUp
    self.bind("KeyPress") do |e|
      yield(e)
    end
  end
end

class TkEntry
  def setText(str)
    self.delete(0,'end')
    self.insert(0,str)
  end

  def getText
    self.get
  end

  def onKeyUp
    self.bind("KeyPress") do |e|
      yield(e)
    end
  end
end

class TkListbox
  def onSelect
    self.bind('<ListboxSelect>') do |e|
      yield(e)
    end
  end
end

class TkRoot
  def onKeyUp
    self.bind("KeyPress") do |e|
      yield(e)
    end
  end
end

class TkLabel
  def setText(str)
    self.delete(0,'end')
    self.insert(0,str)
  end

  def getText
    self.get
  end
end

class TkListbox
  def clear
    self.delete(0, self.size-1)
  end

  def populate(list)
    clear
    list.each{|i| self.insert(self.size,i)}
  end
end
