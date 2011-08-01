#-----------------------------------------------------------------------
#
#  Copyright (C) 2007 Douglas Creager
#
#    This library is free software; you can redistribute it and/or
#    modify it under the terms of the GNU Lesser General Public
#    License as published by the Free Software Foundation; either
#    version 2.1 of the License, or (at your option) any later
#    version.
#
#    This library is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#    Lesser General Public License for more details.
#
#    You should have received a copy of the GNU Lesser General Public
#    License along with this library; if not, write to the Free
#    Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
#    02111-1307 USA
#
#-----------------------------------------------------------------------

require 'rake'
require 'rake/tasklib'

module Rake

  class FigureTask < TaskLib

    attr_accessor :name
    attr_accessor :source
    attr_accessor :eps
    attr_accessor :pdf

    def initialize(name)
      init(name)
      yield self if block_given?
      define unless name.nil?
    end

    def init(name)
      @name = Rake.rootdir + name.to_s.ext(default_source_extension)
      @source = @name
      @eps = @source.ext("eps")
      @pdf = @source.ext("pdf")
    end

    def define
      file @eps => [@source] do
        self.generate_eps
      end

      file @pdf => [@source] do
        self.generate_pdf
      end

      task :figures => [@eps, @pdf]

      task :clean do
        clean_figures
      end
    end

    protected

    def default_source_extension
      "unknown"
    end

    def clean_figures
      rm_f @eps
      rm_f @pdf
    end

    def generate_eps
      raise "FigureTask is abstract"
    end

    def generate_pdf
      raise "FigureTask is abstract"
    end
  end

  class GraffleTask < FigureTask
    def define
      super
      task :graffle => [@eps, @pdf]
    end

    protected

    def default_source_extension
      "graffle"
    end

    def clean_figures
    end

    def generate_eps
      sh %{graffle.sh eps #{@source} #{@eps}}
    end

    def generate_pdf
      sh %{graffle.sh pdf #{@source} #{@pdf}}
    end
  end

  class DiaTask < FigureTask
    def define
      super 
      task @pdf => [@eps]
      task :graffle => [@eps, @pdf]
    end

    protected

    def default_source_extension
      "dia"
    end

    def generate_eps
      sh %{dia -l -t eps-builtin -e #{@eps} #{@source}}
    end

    def generate_pdf
      sh %{epstopdf #{@eps} -o=#{@pdf}}
    end    
  end

  class GnuplotTask < FigureTask
    attr_accessor :fonts, :includes

    def initialize(name, fonts)
      init(name, fonts)
      yield self if block_given?
      define unless name.nil?
    end

    def init(name, fonts)
      super(name)
      @fonts = fonts
      @includes = []
    end

    def define
      @includes.collect! { |f| Rake.rootdir + f }

      file @eps => [@source] + @includes do
        self.generate_eps
      end

      file @pdf => [@eps] do
        self.generate_pdf
      end

      task :figures => [@eps, @pdf]

      task :clean do
        clean_figures
      end

      task :gnuplot => [@eps, @pdf]
    end

    protected

    def default_source_extension
      "gp"
    end

    def generate_eps
      dir = pwd
      cd File.dirname(@source)
      sh %{gnuplot-latex-fonts #{File.basename(@source)} #{@fonts.join(" ")}}
      cd dir
    end

    def generate_pdf
      sh %{epstopdf #{@eps} -o=#{@pdf}}
    end
  end

end

def graffle(name, &block)
  t = Rake::GraffleTask.new(name, &block)
  return t.name
end

def dia(name, &block)
  t = Rake::DiaTask.new(name, &block)
  return t.name
end

def gnuplot(name, fonts, &block)
  fonts = [fonts] if fonts.is_a?(String)
  t = Rake::GnuplotTask.new(name, fonts, &block)
  return t.name
end
