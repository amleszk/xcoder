require 'xcode/project'
require 'nokogiri'

module Xcode
  class Workspace
    
    XCWS_DATA = '/contents.xcworkspacedata'
    
    attr_reader :projects, :name, :path, :schemes
    def initialize(path)
      path = "#{path}.xcworkspace" unless path=~/\.xcworkspace/
      path = "#{path}#{XCWS_DATA}" unless path=~/xcworkspacedata$/
      
      @name = File.basename(path.gsub(/\.xcworkspace\/contents\.xcworkspacedata/,''))
      @projects = []
      @path = File.expand_path path
      doc = Nokogiri::XML(open(@path))
      doc.search("FileRef").each do |file|
        location = file["location"]
        if matcher = location.match(/^group:(.+)$/)
          project_path = "#{workspace_root}/#{matcher[1]}"
          @projects << Xcode::Project.new(project_path)
        end
      end

      @schemes = Scheme.all_from_path(self, @path.gsub(/#{XCWS_DATA}/,''))
    end    
    
    def project(name)
      project = @projects.select {|c| c.name == name.to_s}.first
      raise "No such project #{name}, available projects are #{@projects.map {|c| c.name}.join(', ')}" if project.nil?
      yield project if block_given?
      project
    end
    
    def describe
      puts "Workspace #{name} contains:"
      projects.each do |p|
        p.describe
      end
    end
    
    def workspace_root
      File.dirname(File.dirname(@path))
    end
        
    #
    # Return the scheme with the specified name. Raises an error if no schemes 
    # match the specified name.
    # 
    # @note if two schemes match names, the first matching scheme is returned.
    # 
    # @param [String] name of the specific scheme
    # @return [Scheme] the specific scheme that matches the name specified
    #
    def scheme(name)
      scheme = @schemes.select {|t| t.name == name.to_s}.first
      raise "No such scheme #{name}, available schemes are #{@schemes.map {|t| t.name}.join(', ')}" if scheme.nil?
      yield scheme if block_given?
      scheme
    end
    
  end
end