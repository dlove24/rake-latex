#-----------------------------------------------------------------------
#
#  Copyright (C) 2004 Douglas Creager
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

  # Maintain the directory containing the current Rakefile.
  @@rootdir = nil

  # Called at the start of a Rakefile that contains rules that needs
  # to know the directory that the Rakefile is in.  Adds the current
  # Rakefile's directory to the beginning of the @@rootdir list.
  # Should be called with __FILE__ as the parameter.  This will take
  # care of relative links to the file, allowing it to be required
  # from different current directories.
  def Rake.startfile(file)
    @@rootdir = [] if @@rootdir.nil?
    @@rootdir.unshift(File.dirname(file)+'/')
  end

  # Called at the end of a Rakefile that contains rules that needs to
  # know the directory that the Rakefile is in.  Removes the current
  # Rakefile's directory from the beginning of the @@rootdir list.
  def Rake.endfile()
    @@rootdir.shift
  end

  # Returns the root directory of the current Rakefile.
  def Rake.rootdir
    return "./" if @@rootdir.nil? or @@rootdir.empty?
    return @@rootdir[0]
  end

  class LatexTask < TaskLib

    attr_accessor :name
    attr_accessor :need_aux
    attr_accessor :figures
    attr_accessor :references
    attr_accessor :includes
    attr_accessor :include_dirs
    attr_accessor :tex
    attr_accessor :dvi
    attr_accessor :ps
    attr_accessor :pdf

    def initialize(name)
      init(name)
      yield self if block_given?
      define unless name.nil?
    end

    def init(name)
      @name = Rake.rootdir + name.to_s.ext("tex")
      @need_aux = true
      @figures = []
      @references = []
      @includes = []
      @include_dirs = []
      @latexinputs = nil
      @pdflatexinputs = nil
      @bibtexinputs = nil

      @tex = @name
      @blank = @tex.ext('')
      @dvi = @tex.ext("dvi")
      @ps  = @tex.ext("ps")
      @pdf = @tex.ext("pdf")
    end

    def define
      @includes.collect!     { |f| Rake.rootdir + f }
      @references.collect!   { |f| Rake.rootdir + f }
      @include_dirs.collect! { |f| File.expand_path(Rake.rootdir + f) }

      @epsfigs = @figures.collect { |f| f.ext('.eps') }
      @pdffigs = @figures.collect { |f| f.ext('.pdf') }

      file @dvi => [@tex] + @references + @epsfigs + @includes do
        |task|

        if not @references.empty? then
          self.run_latex(task, true)
          self.run_bibtex(task)
        end

        self.run_latex(task)
      end

      file @ps => [@dvi] do
        |task|
        run_dvips(task)
      end

      file @pdf => [@tex] + @references + @pdffigs + @includes do
        |task|

        if not @references.empty? then
          self.run_pdflatex(task, true)
          self.run_bibtex(task)
        end

        self.run_pdflatex(task)
      end

      task :dvi => @dvi
      task :ps => @ps
      task :pdf => @pdf

      task :clean do
        rm_f @dvi
        rm_f @ps
        rm_f @pdf
        rm_f @tex.ext("aux")
        rm_f @tex.ext("log")
        rm_f @tex.ext("toc")

        unless @references.empty? then
          rm_f @tex.ext("bbl")
          rm_f @tex.ext("blg")
        end
      end
    end

    protected

    def collect_prereq_dirs(prereqs, exts)
      dirs_hash = Hash.new
      dirs = []

      prereqs.each do
        |f|
        if exts.include? File.extname(f) then
          path = File.expand_path(File.dirname(f))
          if not dirs_hash.include?(path) then
            dirs.push(path)
            dirs_hash[path] = true
          end
        end
      end

      return dirs
    end

    def make_env(var,dirs)
      return "" if dirs.nil? or dirs.empty?

      return %{#{var}=#{dirs.join(':')}:\$\{#{var}\}}
    end

    def run_latex_once
      sh %{#{@latexinputs} latex #{File.basename(@blank)}}
    end

    def run_latex(task, once=false)
      if @latexinputs.nil? then
        dirs = collect_prereq_dirs(task.prerequisites,['.eps'])
        dirs |= @include_dirs
        @latexinputs = make_env('TEXINPUTS',dirs)
      end

      cd File.dirname(@tex) do
        run_latex_once
        run_latex_once if @need_aux and not once
      end
    end

    def run_dvips(task)
      if @latexinputs.nil? then
        dirs = collect_prereq_dirs(task.prerequisites,['.eps'])
        dirs |= @include_dirs
        @latexinputs = make_env('TEXINPUTS',dirs)
      end

      sh %{#{@latexinputs} dvips #{@dvi} -o #{@ps}}
    end

    def run_pdflatex_once
      sh %{#{@pdflatexinputs} pdflatex #{File.basename(@blank)}}
    end

    def run_pdflatex(task, once=false)
      if @pdflatexinputs.nil? then
        dirs = collect_prereq_dirs(task.prerequisites,['.pdf'])
        dirs |= @include_dirs
        @pdflatexinputs = make_env('TEXINPUTS',dirs)
      end

      cd File.dirname(@tex) do
        run_pdflatex_once
        run_pdflatex_once if @need_aux and not once
      end
    end

    def run_bibtex(task)
      if @bibtexinputs.nil? then
        dirs = collect_prereq_dirs(task.prerequisites,['.bib'])
        @bibtexinputs = make_env('BIBINPUTS',dirs)
      end

      cd File.dirname(@tex) do
        sh %{#{@bibtexinputs} bibtex #{File.basename(@blank)}}
      end
    end

  end

end


def latex(name,&block)
  t = Rake::LatexTask.new(name,&block)
  return t.name
end

