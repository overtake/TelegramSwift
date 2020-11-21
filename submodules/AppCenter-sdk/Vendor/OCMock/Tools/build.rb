#!/usr/bin/env ruby
   
class Builder

    def initialize
        @env = Environment.new()
        @worker = CompositeWorker.new([Logger.new(), Executer.new()])
    end              
    
    def makeRelease
      createWorkingDirectories
      downloadSource
      copySource
      buildModules
      signFrameworks "erik@doernenburg.com"
      createPackage "ocmock-3.7.1.dmg", "OCMock 3.7.1"
      sanityCheck
      openPackageDir
    end
    
    def justBuild
      createWorkingDirectories
      downloadSource
      buildModules
      openPackageDir
    end
    
    def createWorkingDirectories
        @worker.run("mkdir -p #{@env.sourcedir}")
        @worker.run("mkdir -p #{@env.productdir}")
        @worker.run("mkdir -p #{@env.packagedir}")
    end
    
    def downloadSource
        @worker.run("git archive master | tar -x -v -C #{@env.sourcedir}")
    end

    def copySource
        @worker.run("cp -R #{@env.sourcedir}/Source #{@env.productdir}")
    end

    def buildModules
        @worker.chdir("#{@env.sourcedir}/Source")
        
        @worker.run("xcodebuild -project OCMock.xcodeproj -target OCMock OBJROOT=#{@env.objroot} SYMROOT=#{@env.symroot}")
        osxproductdir = "#{@env.productdir}/macOS"                                        
        @worker.run("mkdir -p #{osxproductdir}")
        @worker.run("cp -R #{@env.symroot}/Release/OCMock.framework #{osxproductdir}")

        @worker.run("xcodebuild -project OCMock.xcodeproj -target OCMockLib -sdk iphoneos14.2 OBJROOT=#{@env.objroot} SYMROOT=#{@env.symroot}")
        @worker.run("xcodebuild -project OCMock.xcodeproj -target OCMockLib -sdk iphonesimulator14.2 OBJROOT=#{@env.objroot} SYMROOT=#{@env.symroot}")
        ioslibproductdir = "#{@env.productdir}/iOS\\ library"                                           
        @worker.run("mkdir -p #{ioslibproductdir}")
        @worker.run("cp -R #{@env.symroot}/Release-iphoneos/OCMock #{ioslibproductdir}")
        @worker.run("lipo -create -output #{ioslibproductdir}/libOCMock.a #{@env.symroot}/Release-iphoneos/libOCMock.a #{@env.symroot}/Release-iphonesimulator/libOCMock.a")
        
        @worker.run("xcodebuild -project OCMock.xcodeproj -target 'OCMock iOS' -sdk iphoneos14.2 OBJROOT=#{@env.objroot} SYMROOT=#{@env.symroot}")
        iosproductdir = "#{@env.productdir}/iOS\\ framework"                                           
        @worker.run("mkdir -p #{iosproductdir}")
        @worker.run("cp -R #{@env.symroot}/Release-iphoneos/OCMock.framework #{iosproductdir}")
 
        @worker.run("xcodebuild -project OCMock.xcodeproj -target 'OCMock tvOS' -sdk appletvos14.2 OBJROOT=#{@env.objroot} SYMROOT=#{@env.symroot}")
        tvosproductdir = "#{@env.productdir}/tvOS"                                           
        @worker.run("mkdir -p #{tvosproductdir}")
        @worker.run("cp -R #{@env.symroot}/Release-appletvos/OCMock.framework #{tvosproductdir}")

        @worker.run("xcodebuild -project OCMock.xcodeproj -target 'OCMock watchOS' -sdk watchos7.1 OBJROOT=#{@env.objroot} SYMROOT=#{@env.symroot}")
        watchosproductdir = "#{@env.productdir}/watchOS"                                           
        @worker.run("mkdir -p #{watchosproductdir}")
        @worker.run("cp -R #{@env.symroot}/Release-watchos/OCMock.framework #{watchosproductdir}")
    end
    
    def signFrameworks(identity)
        osxproductdir = "#{@env.productdir}/macOS"
        iosproductdir = "#{@env.productdir}/iOS\\ framework"
        tvosproductdir = "#{@env.productdir}/tvOS"
        watchosproductdir = "#{@env.productdir}/watchOS"

        @worker.run("codesign -f -s 'Apple Development: #{identity}' #{osxproductdir}/OCMock.framework")
        @worker.run("codesign -f -s 'Apple Development: #{identity}' #{iosproductdir}/OCMock.framework")
        @worker.run("codesign -f -s 'Apple Development: #{identity}' #{tvosproductdir}/OCMock.framework")
        @worker.run("codesign -f -s 'Apple Development: #{identity}' #{watchosproductdir}/OCMock.framework")
    end

    def createPackage(packagename, volumename)    
        @worker.chdir(@env.packagedir)  
        @worker.run("hdiutil create -size 7m temp.dmg -layout NONE") 
        disk_id = nil
        @worker.run("hdid -nomount temp.dmg") { |hdid| disk_id = hdid.readline.split[0] }
        @worker.run("newfs_hfs -v '#{volumename}' #{disk_id}")
        @worker.run("hdiutil eject #{disk_id}")
        @worker.run("hdid temp.dmg") { |hdid| disk_id = hdid.readline.split[0] }
        @worker.run("cp -R #{@env.productdir}/* '/Volumes/#{volumename}'")
        @worker.run("hdiutil eject #{disk_id}")
        @worker.run("hdiutil convert -format UDZO temp.dmg -o #{@env.packagedir}/#{packagename} -imagekey zlib-level=9")
        @worker.run("rm temp.dmg")
    end           
    
    def openPackageDir
        @worker.run("open #{@env.packagedir}") 
    end
    
    def sanityCheck
        osxproductdir = "#{@env.productdir}/macOS"                                        
        ioslibproductdir = "#{@env.productdir}/iOS\\ library"                                           
        iosproductdir = "#{@env.productdir}/iOS\\ framework"                                           
        tvosproductdir = "#{@env.productdir}/tvOS"                                           
        watchosproductdir = "#{@env.productdir}/watchOS"                                           

        archs = nil
        @worker.run("lipo -info #{osxproductdir}/OCMock.framework/OCMock") { |lipo| archs = /re: (.*)/.match(lipo.readline)[1].strip() }
        puts "^^ wrong architecture for macOS framework; found: #{archs}\n\n" unless archs == "x86_64 arm64"
        @worker.run("lipo -info #{ioslibproductdir}/libOCMock.a") { |lipo| archs = /re: (.*)/.match(lipo.readline)[1].strip() }
        puts "^^ wrong architectures for iOS library; found: #{archs}\n\n" unless archs == "armv7 i386 x86_64 arm64"
        @worker.run("lipo -info #{iosproductdir}/OCMock.framework/OCMock")  { |lipo| archs = /re: (.*)/.match(lipo.readline)[1].strip() }
        puts "^^ wrong architectures for iOS framework; found: #{archs}\n\n" unless archs == "armv7 arm64"
        @worker.run("lipo -info #{tvosproductdir}/OCMock.framework/OCMock")  { |lipo| archs = /re: (.*)/.match(lipo.readline)[1].strip() }
        puts "^^ wrong architectures for tvOS framework; found: #{archs}\n\n" unless archs == "arm64"
        @worker.run("lipo -info #{watchosproductdir}/OCMock.framework/OCMock")  { |lipo| archs = /re: (.*)/.match(lipo.readline)[1].strip() }
        puts "^^ wrong architectures for watchOS framework; found: #{archs}\n\n" unless archs == "armv7k arm64_32"

        @worker.run("codesign -dvv #{osxproductdir}/OCMock.framework")
        @worker.run("codesign -dvv #{iosproductdir}/OCMock.framework")       
        @worker.run("codesign -dvv #{tvosproductdir}/OCMock.framework")
        @worker.run("codesign -dvv #{watchosproductdir}/OCMock.framework")
    end
    
    def upload(packagename, dest)
        @worker.run("scp #{@env.packagedir}/#{packagename} #{dest}")
    end
    
    def cleanup
        @worker.run("chmod -R u+w #{@env.tmpdir}")
        @worker.run("rm -rf #{@env.tmpdir}");
    end
    
end


## Environment
## use attributes to configure manager for your environment

class Environment
    def initialize()
        @tmpdir = "/tmp/ocmock.#{Process.pid}"
        @sourcedir = tmpdir + "/Source"
        @productdir = tmpdir + "/Products"
        @packagedir = tmpdir
        @objroot = tmpdir + '/Build/Intermediates'
        @symroot = tmpdir + '/Build'
    end
    
    attr_accessor :tmpdir, :sourcedir, :productdir, :packagedir, :objroot, :symroot
end


## Logger (Worker)
## prints commands

class Logger
    def chdir(dir)
        puts "## chdir #{dir}"
    end
    
    def run(cmd)
        puts "## #{cmd}"
    end
end


## Executer (Worker)
## actually runs commands

class Executer
    def chdir(dir)
        Dir.chdir(dir)
    end

    def run(cmd, &block)     
        if block == nil
          if !system(cmd)
            puts "** command failed with error"
            exit
          end
        else
          IO.popen(cmd, &block)
        end
    end
end


## Composite Worker (Worker)
## sends commands to multiple workers

class CompositeWorker
    def initialize(workers)
        @workers = workers
    end
    
    def chdir(dir)
        @workers.each { |w| w.chdir(dir) }
    end

    def run(cmd)
         @workers.each { |w| w.run(cmd) }
    end
 
    def run(cmd, &block)
         @workers.each { |w| w.run(cmd, &block) }
    end
end    


if /Tools$/.match(Dir.pwd)
  Dir.chdir("..")
end

if ARGV[0] == '-r' 
  Builder.new.makeRelease
else
  Builder.new.justBuild
end


