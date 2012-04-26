require 'nokogiri'

module Xcode
  
  # Schemes are an XML file that describe build, test, launch and profile actions
  # For the purposes of Xcoder, we want to be able to build and test
  # The scheme's build action only describes a target, so we need to look at launch for the config
  class Scheme
    
    # Schemes can be defined as `shared` schemes and then `user` specific schemes. Parsing
    # the schemes will load the shared ones and then the current acting user's
    # schemes.
    # 
    # @return [Array<Scheme>] the shared schemes and user specific schemes found
    #   within the projet at the path defined for schemes.
    # 
    def self.all_from_path(container, path)
      shared_schemes = Dir["#{path}/xcshareddata/xcschemes/*.xcscheme"]
      user_specific_schemes = Dir["#{path}/xcuserdata/#{ENV['USER']}.xcuserdatad/xcschemes/*.xcscheme"]
      
      (shared_schemes + user_specific_schemes).map do |scheme|
        Xcode::Scheme.new(container, scheme)
      end
    end
    
    attr_reader :container, :path, :name, :launch, :test
    def initialize(container, path)
      @container = container
      @path = File.expand_path(path)
      @name = File.basename(path).gsub(/\.xcscheme$/,'')
      doc = Nokogiri::XML(open(@path))
      
      @launch = parse_action(doc, 'launch')
      @test = parse_action(doc, 'test')
    end
    
    def builder
      Xcode::Builder.new(self)
    end
    
    def workspace?
      @container.is_a? Xcode::Workspace
    end
    
    private 
    
    def parse_action(doc, action_name)
      action = doc.xpath("//#{action_name.capitalize}Action").first
      buildableReference = action.xpath('BuildableProductRunnable/BuildableReference').first
      return nil if buildableReference.nil?
      
      target_name = buildableReference['BlueprintName']
      project = nil
      if(workspace?) 
        project_name = buildableReference['ReferencedContainer'].match(/\/(.*)\.xcodeproj/)[1]
        project = @container.project project_name
      else
        project = @container
      end
      project.target(target_name).config(action['buildConfiguration'])
    end

  end
end