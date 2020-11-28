To set up this example, open Example.xcodeproj:

1. Drag OCHamcrestIOS.framework into the project, specifying:
  * "Copy items into destination group's folder"
  * Add to targets: ExampleTests
2. In Build Settings, add -ObjC to "Other Linker Flags". Whether you do this at
   the target level or project level doesn't matter, as long as the change is
   applied to the ExampleTests target.


Then command-U to run unit tests. Try changing one of the tests to fail.

