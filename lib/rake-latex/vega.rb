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

  VEGA_EXTS = {
    'relaxng' => 'rnc',
    'carp'    => 'carp',
    'latex'   => 'tex'
  }

  class VegaTask < TaskLib
    attr_accessor :name, :source, :dest, :language, :output

    def initialize(name, language, output)
      init(name, language, output)
      yield self if block_given?
      define
    end

    def init(name, language, output)
      source_ext = VEGA_EXTS[language]
      source_file = name.to_s.ext(source_ext)

      dest_ext = VEGA_EXTS[output]
      dest_file = name.to_s.ext(dest_ext)

      @name = dest_file
      @source = Rake.rootdir + source_file
      @dest = Rake.rootdir + dest_file
      @language = language
      @output = output
    end

    def define
      file @dest => [@source] do
        sh %{vega -l #{@language} -o #{@output} #{@source} #{@dest}}
      end

      task :listings => [@dest]

      task :clean do
        rm_f @dest
      end
    end
  end

end

def vega(name, language, output, &block)
  t = Rake::VegaTask.new(name, language, output, &block)
  return t.name
end
