require 'tempfile'
require 'securerandom'

#Specifications for the ./bin/flok utility

def new_temp_dir
  #Get a new temporary directory
  temp = Tempfile.new SecureRandom.hex
  path = temp.path
  temp.close!

  FileUtils.mkdir_p path
  return path
end

#Execute flok binary
def flok args
  #Get path to the flok binary relative to this file
  bin_path = File.join(File.dirname(__FILE__), "../../bin/flok")

  #Now execute the command with a set of arguments
  system("#{bin_path} #{args}")
end

#Create a new flok project named test and go into that directory
def flok_new 
  temp_dir = new_temp_dir
  Dir.chdir temp_dir do
    flok "new test"
    Dir.chdir "test" do
      yield
    end
  end
end

def dirs
  Dir["*"].select{|e| File.directory?(e)}
end

def files
  Dir["*"].select{|e| File.file?(e)}
end

RSpec.describe "CLI" do
  it "Can create a new project with correct directories" do
    flok_new do
      #Check directories
      expect(dirs).to include("app")
    end
  end

  it "Can build a project" do
    flok_new do
      #Build a new project
      flok "build CHROME"

      #Check it's products directory
      expect(dirs).to include "products"
      Dir.chdir "products" do
        #Has a platform folder
        expect(dirs).to include "CHROME"
        Dir.chdir "CHROME" do
          #Has an application_user.js file
          expect(files).to include "application_user.js"
          expect(files).not_to include "application.js"
          expect(files).not_to include "user_compiler.js"

          #Contains the same files as the kernel in the drivers directory
          expect(dirs).to include "drivers"
        end
      end
    end
  end
end
